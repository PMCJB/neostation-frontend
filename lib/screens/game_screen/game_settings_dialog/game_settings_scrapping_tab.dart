import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/models/game_model.dart';
import 'package:neostation/models/system_model.dart';
import 'package:neostation/providers/file_provider.dart';
import 'package:neostation/repositories/game_repository.dart';
import 'package:neostation/repositories/scraper_repository.dart';
import 'package:neostation/repositories/system_repository.dart';
import 'package:neostation/screens/game_screen/my_games_grid.dart';
import 'package:neostation/services/logger_service.dart';
import 'package:neostation/services/screenscraper_service.dart';
import 'package:neostation/services/sfx_service.dart';
import 'package:neostation/widgets/custom_notification.dart';

/// Scrapping tab for [GameSettingsDialog]: force rescrape plus manual
/// metadata (title, descriptions, developer, publisher, genre) and artwork
/// (screenshot, wheel, fanart, boxart) editing.
class GameSettingsScrappingTab extends StatefulWidget {
  final GameModel game;
  final SystemModel system;
  final FileProvider fileProvider;
  final bool isAllMode;
  final VoidCallback? onGameUpdated;

  const GameSettingsScrappingTab({
    super.key,
    required this.game,
    required this.system,
    required this.fileProvider,
    required this.isAllMode,
    this.onGameUpdated,
  });

  @override
  State<GameSettingsScrappingTab> createState() =>
      GameSettingsScrappingTabState();
}

class GameSettingsScrappingTabState extends State<GameSettingsScrappingTab> {
  static final _log = LoggerService.instance;

  // ── Navigation entries ──────────────────────────────────────────────────
  static const int _idxRescrape = 0;
  static const int _idxTitle = 1;
  static const int _idxDeveloper = 2;
  static const int _idxPublisher = 3;
  static const int _idxGenre = 4;
  static const int _idxDescStart = 5; // en, es, fr, de, it, pt (6 entries)
  static const int _idxImageStart = 11; // screenshot, wheel, fanart, boxart
  static const int _idxSave = 15;
  static const int _totalItems = 16;

  static const _descLanguages = ['en', 'es', 'fr', 'de', 'it', 'pt'];
  static const _imageTypes = ['screenshots', 'wheels', 'fanarts', 'box2d'];

  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  // Text editing
  final _titleController = TextEditingController();
  final _developerController = TextEditingController();
  final _publisherController = TextEditingController();
  final _genreController = TextEditingController();
  final Map<String, TextEditingController> _descControllers = {
    for (final lang in _descLanguages) lang: TextEditingController(),
  };
  final Map<int, FocusNode> _fieldFocusNodes = {};
  int? _editingFieldIndex;

  // Async state
  bool _isScraping = false;
  double _scrapeProgress = 0;
  bool _isSaving = false;
  int _thumbsVersion = 0;

  GlobalKey _itemKey(int navIndex) =>
      _itemKeys.putIfAbsent(navIndex, () => GlobalKey());

  FocusNode _focusNodeFor(int navIndex) => _fieldFocusNodes.putIfAbsent(
    navIndex,
    () => FocusNode()..addListener(() => _onFieldFocusChanged(navIndex)),
  );

  /// True while a metadata text field holds focus — the host dialog turns B
  /// into 'leave the field' instead of 'close' in that state.
  bool get isEditingText => _editingFieldIndex != null;

  String? get _systemId => widget.game.systemId ?? widget.system.id;

  String get _folder => widget.isAllMode && widget.game.systemFolderName != null
      ? widget.game.systemFolderName!
      : widget.system.primaryFolderName;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _developerController.dispose();
    _publisherController.dispose();
    _genreController.dispose();
    for (final c in _descControllers.values) {
      c.dispose();
    }
    for (final n in _fieldFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────

  Future<void> _loadMetadata() async {
    final systemId = _systemId;
    Map<String, dynamic>? row;
    if (systemId != null) {
      row = await ScraperRepository.getGameMetadata(
        systemId,
        widget.game.romname,
      );
    }
    if (!mounted) return;
    setState(() {
      _titleController.text =
          (row?['real_name'] as String?) ??
          (widget.game.name.isNotEmpty ? widget.game.name : '');
      _developerController.text =
          (row?['developer'] as String?) ?? widget.game.developer;
      _publisherController.text =
          (row?['publisher'] as String?) ?? widget.game.publisher;
      _genreController.text = (row?['genre'] as String?) ?? widget.game.genre;
      for (final lang in _descLanguages) {
        // Exact-language values only — getDescriptionForLanguage would leak
        // the EN fallback into other languages' fields.
        _descControllers[lang]!.text =
            (row?['description_$lang'] as String?) ??
            widget.game.descriptions?[lang] ??
            '';
      }
    });
  }

  Future<void> _saveMetadata() async {
    final systemId = _systemId;
    if (systemId == null || _isSaving) return;
    setState(() => _isSaving = true);

    String? nullable(String text) {
      final trimmed = text.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final fields = <String, dynamic>{
      'real_name': nullable(_titleController.text),
      'developer': nullable(_developerController.text),
      'publisher': nullable(_publisherController.text),
      'genre': nullable(_genreController.text),
      for (final lang in _descLanguages)
        'description_$lang': nullable(_descControllers[lang]!.text),
    };

    final ok = await ScraperRepository.updateGameMetadata(
      systemId,
      widget.game.romname,
      fields,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    AppNotification.showNotification(
      context,
      ok
          ? AppLocale.metadataSaved.getString(context)
          : AppLocale.failedToSaveSetting.getString(context),
      type: ok ? NotificationType.success : NotificationType.error,
    );
    if (ok) widget.onGameUpdated?.call();
  }

  // ── Force rescrape ──────────────────────────────────────────────────────

  List<String> _artworkPaths() {
    final folder = _folder;
    return [
      widget.game.getImagePath(folder, 'fanarts', widget.fileProvider),
      widget.game.getImagePath(folder, 'wheels', widget.fileProvider),
      widget.game.getImagePath(folder, 'box2d', widget.fileProvider),
      widget.game.getScreenshotPath(folder, widget.fileProvider),
    ];
  }

  Future<void> _forceRescrape() async {
    if (_isScraping) return;
    final romPath = widget.game.romPath;
    if (romPath == null) return;

    setState(() {
      _isScraping = true;
      _scrapeProgress = 0;
    });

    // Resolve the real system (not the favorites/all virtual one).
    SystemModel targetSystem = widget.system;
    if (widget.isAllMode && widget.game.systemFolderName != null) {
      final original = await SystemRepository.getSystemByFolderName(
        widget.game.systemFolderName!,
      );
      if (original != null) targetSystem = original;
    }

    final systemId = targetSystem.id;
    if (systemId == null) {
      if (mounted) setState(() => _isScraping = false);
      return;
    }

    try {
      final result = await ScreenScraperService.scrapeSingleGame(
        appSystemId: systemId,
        romName: widget.game.romname,
        systemFolder: targetSystem.primaryFolderName,
        romPath: romPath,
        gameName: widget.game.name,
        forceOverwrite: true,
        onProgress: (status, progress) {
          if (mounted) setState(() => _scrapeProgress = progress);
        },
      );

      // Bust cached artwork so the fresh media shows up everywhere.
      for (final path in _artworkPaths()) {
        final file = File(path);
        if (await file.exists()) {
          await FileImage(file).evict();
        }
      }
      GamesGrid.evictArtworkCaches(_artworkPaths());

      if (mounted) {
        AppNotification.showNotification(
          context,
          result['success'] == true
              ? 'Scraping completed'
              : 'Scraping failed: ${result['message']}',
          type: result['success'] == true
              ? NotificationType.success
              : NotificationType.error,
        );
      }
      if (result['success'] == true) {
        await _loadMetadata();
        if (mounted) setState(() => _thumbsVersion++);
        widget.onGameUpdated?.call();
      }
    } catch (e) {
      _log.e('Force rescrape failed: $e');
    } finally {
      if (mounted) setState(() => _isScraping = false);
    }
  }

  // ── Artwork replacement ─────────────────────────────────────────────────

  String _pathForImageType(String type) => type == 'screenshots'
      ? widget.game.getScreenshotPath(_folder, widget.fileProvider)
      : widget.game.getImagePath(_folder, type, widget.fileProvider);

  Future<void> _replaceImage(String type) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final srcPath = result?.files.single.path;
    if (srcPath == null || !mounted) return;

    try {
      final targetPath = _pathForImageType(type);
      await File(targetPath).parent.create(recursive: true);
      await File(srcPath).copy(targetPath);
      await FileImage(File(targetPath)).evict();
      GamesGrid.evictArtworkCaches([targetPath]);

      // Keep the grid's layout math correct for the new boxart dimensions.
      if (type == 'box2d' && widget.game.systemId != null) {
        final bytes = await File(targetPath).readAsBytes();
        final decoded = await decodeImageFromList(bytes);
        await GameRepository.updateBox2dAspectRatio(
          widget.game.systemId!,
          widget.game.romname,
          '${decoded.width}/${decoded.height}',
        );
      }

      if (!mounted) return;
      setState(() => _thumbsVersion++);
      widget.onGameUpdated?.call();
      AppNotification.showNotification(
        context,
        AppLocale.imageUpdated.getString(context),
        type: NotificationType.success,
      );
    } catch (e) {
      _log.e('Artwork replacement failed: $e');
      if (mounted) {
        AppNotification.showNotification(
          context,
          AppLocale.failedToSaveSetting.getString(context),
          type: NotificationType.error,
        );
      }
    }
  }

  // ── Gamepad delegates ───────────────────────────────────────────────────

  void moveUp() {
    _unfocusActiveField();
    // Schedule the selection change after the field blur settles to avoid
    // nested setState from the FocusNode listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _totalItems - 1);
      });
      _scrollToSelectedItem();
    });
  }

  void moveDown() {
    _unfocusActiveField();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _totalItems - 1);
      });
      _scrollToSelectedItem();
    });
  }

  void trigger() {
    final idx = _selectedIndex;
    if (idx == _idxRescrape) {
      _forceRescrape();
    } else if (idx >= _idxTitle && idx < _idxImageStart) {
      _focusNodeFor(idx).requestFocus();
    } else if (idx >= _idxImageStart && idx < _idxSave) {
      _replaceImage(_imageTypes[idx - _idxImageStart]);
    } else if (idx == _idxSave) {
      _saveMetadata();
    }
  }

  /// Leaves the currently edited text field (used by the host on B).
  void cancelEdit() => _unfocusActiveField();

  void _unfocusActiveField() {
    final idx = _editingFieldIndex;
    if (idx == null) return;
    _fieldFocusNodes[idx]?.unfocus();
  }

  void _onFieldFocusChanged(int navIndex) {
    final node = _fieldFocusNodes[navIndex];
    if (node == null) return;
    setState(() {
      _editingFieldIndex = node.hasFocus ? navIndex : null;
    });
  }

  void _scrollToSelectedItem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[_selectedIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      // Tapping outside a text field leaves edit mode.
      onTap: _unfocusActiveField,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Force Rescrape.
            _NavRow(
              key: _itemKey(_idxRescrape),
              isSelected: _selectedIndex == _idxRescrape,
              icon: Symbols.refresh_rounded,
              label: AppLocale.forceRescrape.getString(context),
              subtitle: _isScraping
                  ? '${AppLocale.scraping.getString(context)} '
                        '${(_scrapeProgress * 100).toInt()}%'
                  : AppLocale.rescrape.getString(context),
              trailing: _isScraping
                  ? SizedBox(
                      width: 60.r,
                      child: LinearProgressIndicator(
                        value: _scrapeProgress > 0 ? _scrapeProgress : null,
                        minHeight: 4.r,
                        backgroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                SfxService().playNavSound();
                setState(() => _selectedIndex = _idxRescrape);
                _forceRescrape();
              },
            ),

            _SectionHeader(
              icon: Symbols.edit_rounded,
              label: AppLocale.description.getString(context),
            ),
            _MetadataFieldRow(
              key: _itemKey(_idxTitle),
              isSelected: _selectedIndex == _idxTitle,
              label: AppLocale.gameTitle.getString(context),
              controller: _titleController,
              focusNode: _focusNodeFor(_idxTitle),
              onTap: () => setState(() => _selectedIndex = _idxTitle),
            ),
            _MetadataFieldRow(
              key: _itemKey(_idxDeveloper),
              isSelected: _selectedIndex == _idxDeveloper,
              label: AppLocale.developer.getString(context),
              controller: _developerController,
              focusNode: _focusNodeFor(_idxDeveloper),
              onTap: () => setState(() => _selectedIndex = _idxDeveloper),
            ),
            _MetadataFieldRow(
              key: _itemKey(_idxPublisher),
              isSelected: _selectedIndex == _idxPublisher,
              label: AppLocale.publisher.getString(context),
              controller: _publisherController,
              focusNode: _focusNodeFor(_idxPublisher),
              onTap: () => setState(() => _selectedIndex = _idxPublisher),
            ),
            _MetadataFieldRow(
              key: _itemKey(_idxGenre),
              isSelected: _selectedIndex == _idxGenre,
              label: AppLocale.genre.getString(context),
              controller: _genreController,
              focusNode: _focusNodeFor(_idxGenre),
              onTap: () => setState(() => _selectedIndex = _idxGenre),
            ),
            for (int i = 0; i < _descLanguages.length; i++)
              _MetadataFieldRow(
                key: _itemKey(_idxDescStart + i),
                isSelected: _selectedIndex == _idxDescStart + i,
                label:
                    '${AppLocale.description.getString(context)} '
                    '(${_descLanguages[i].toUpperCase()})',
                controller: _descControllers[_descLanguages[i]]!,
                focusNode: _focusNodeFor(_idxDescStart + i),
                maxLines: 3,
                onTap: () => setState(() => _selectedIndex = _idxDescStart + i),
              ),

            _SectionHeader(
              icon: Symbols.image_rounded,
              label: AppLocale.systemArt.getString(context),
            ),
            for (int i = 0; i < _imageTypes.length; i++)
              _ArtworkRow(
                key: _itemKey(_idxImageStart + i),
                isSelected: _selectedIndex == _idxImageStart + i,
                label: _imageTypeLabel(context, _imageTypes[i]),
                imagePath: _pathForImageType(_imageTypes[i]),
                thumbsVersion: _thumbsVersion,
                onTap: () {
                  SfxService().playNavSound();
                  setState(() => _selectedIndex = _idxImageStart + i);
                  _replaceImage(_imageTypes[i]);
                },
              ),

            SizedBox(height: 8.r),
            _NavRow(
              key: _itemKey(_idxSave),
              isSelected: _selectedIndex == _idxSave,
              icon: Symbols.save_rounded,
              label: AppLocale.save.getString(context),
              subtitle: '',
              trailing: _isSaving
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.secondary,
                      ),
                    )
                  : null,
              onTap: () {
                SfxService().playNavSound();
                setState(() => _selectedIndex = _idxSave);
                _saveMetadata();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _imageTypeLabel(BuildContext context, String type) {
    switch (type) {
      case 'screenshots':
        return AppLocale.screenshot.getString(context);
      case 'wheels':
        return AppLocale.wheel.getString(context);
      case 'fanarts':
        return AppLocale.fanart.getString(context);
      case 'box2d':
        return AppLocale.boxart.getString(context);
      default:
        return type;
    }
  }
}

/// Small section header with icon, matching the settings-tab aesthetic.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 4.r, top: 8.r, bottom: 4.r),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12.r,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          SizedBox(width: 4.r),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.r,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigable action row (rescrape / save) with optional trailing widget.
class _NavRow extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavRow({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 4.r),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 6.r),
        child: Row(
          children: [
            Container(
              width: 18.r,
              height: 18.r,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                    : theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface,
                size: 11.r,
              ),
            ),
            SizedBox(width: 8.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface,
                      fontSize: 12.r,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 10.r,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Compact metadata text field row; focusable via gamepad trigger.
class _MetadataFieldRow extends StatelessWidget {
  final bool isSelected;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLines;
  final VoidCallback onTap;

  const _MetadataFieldRow({
    super.key,
    required this.isSelected,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        onTap();
        focusNode.requestFocus();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 4.r),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: focusNode.hasFocus
                ? theme.colorScheme.secondary.withValues(alpha: 0.6)
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: 1.r,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92.r,
              child: Padding(
                padding: EdgeInsets.only(top: 4.r),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 10.r,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              // Field-level key handling: while the field is focused the
              // global gamepad/keyboard layer stays out of the way, so Escape
              // (and Enter on single-line fields) is the way back out.
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    focusNode.unfocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: maxLines,
                  minLines: 1,
                  onSubmitted: maxLines == 1
                      ? (_) => focusNode.unfocus()
                      : null,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 11.r,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Artwork row with a live thumbnail and a change action.
class _ArtworkRow extends StatelessWidget {
  final bool isSelected;
  final String label;
  final String imagePath;
  final int thumbsVersion;
  final VoidCallback onTap;

  const _ArtworkRow({
    super.key,
    required this.isSelected,
    required this.label,
    required this.imagePath,
    required this.thumbsVersion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(imagePath);
    final exists = file.existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 4.r),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: Container(
                width: 40.r,
                height: 40.r,
                color: theme.colorScheme.surfaceContainerHighest,
                child: exists
                    ? Image.file(
                        file,
                        key: ValueKey('thumb_${imagePath}_$thumbsVersion'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Symbols.broken_image_rounded,
                          size: 16.r,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      )
                    : Icon(
                        Symbols.image_rounded,
                        size: 16.r,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 8.r),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface,
                  fontSize: 12.r,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 3.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                  width: 1.r,
                ),
              ),
              child: Text(
                AppLocale.change.getString(context),
                style: TextStyle(
                  fontSize: 11.r,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
