import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/providers/neo_sync_provider.dart';
import 'package:neostation/utils/gamepad_nav.dart';
import 'package:neostation/models/system_model.dart';
import 'package:neostation/repositories/neosync_save_folder_repository.dart';
import 'package:neostation/repositories/system_repository.dart';
import 'package:neostation/services/permission_service.dart';
import 'package:neostation/services/user_data_location_service.dart';
import 'package:neostation/widgets/custom_notification.dart' as custom;
import 'package:neostation/widgets/tv_directory_picker.dart';
import 'package:neostation/services/logger_service.dart';
import 'package:neostation/services/gamepad/gamepad_navigation_manager.dart';
import '../../app_screen.dart';
import 'custom_save_folders_panel.dart';
import 'neo_sync_shared.dart';

/// Full-screen Custom Save Folders view.
///
/// Lets the user configure per-emulator custom save folders (ARMSX2, DuckStation,
/// ...). Folder selection runs on this view (which survives Android
/// backgrounding while the SAF picker is open), and each configured folder can
/// be re-synced or removed. Replaces the inline panel with its own navigation
/// layer.
class CustomSaveFoldersView extends StatefulWidget {
  final VoidCallback onBack;

  const CustomSaveFoldersView({super.key, required this.onBack});

  @override
  State<CustomSaveFoldersView> createState() => _CustomSaveFoldersViewState();
}

class _CustomSaveFoldersViewState extends State<CustomSaveFoldersView> {
  static final _log = LoggerService.instance;

  late GamepadNavigation _gamepadNav;

  List<SystemModel> _systems = [];
  List<(String, String, String)> _configured = [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _initializeGamepad();
  }

  @override
  void dispose() {
    GamepadNavigationManager.popLayer('neo_sync_custom_folders');
    _gamepadNav.dispose();
    super.dispose();
  }

  void _initializeGamepad() {
    _gamepadNav = GamepadNavigation(
      onPreviousTab: () => AppNavigation.previousTab(),
      onNextTab: () => AppNavigation.nextTab(),
      onBack: () {
        if (mounted) widget.onBack();
      },
      onSelectItem: _openConfigDialog,
      onSettings: () {},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gamepadNav.initialize();
      GamepadNavigationManager.pushLayer(
        'neo_sync_custom_folders',
        onActivate: () => _gamepadNav.activate(),
        onDeactivate: () => _gamepadNav.deactivate(),
      );
    });
  }

  Future<void> _load() async {
    try {
      final systems = await SystemRepository.getAllSystems();
      final withEmulators = systems
          .where((s) => s.neosync.sync || s.folderName.isNotEmpty)
          .toList();
      if (mounted) setState(() => _systems = withEmulators);
    } catch (e) {
      // Non-fatal.
    }
    await _loadConfigured();
  }

  Future<void> _loadConfigured() async {
    try {
      final configured = await NeoSyncSaveFolderRepository.getAllEntries();
      if (mounted) setState(() => _configured = configured);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _selectFolderFor(String system, String emulatorSlug) async {
    _log.i('CustomSaveFolder: picker start for $system / $emulatorSlug');
    try {
      String? selected;
      final isTV = await PermissionService.isTelevision();
      if (!mounted) return;

      if (isTV) {
        selected = await TvDirectoryPicker.show(context);
      } else {
        final uri = await PermissionService.requestFolderAccess();
        if (uri != null) {
          final hasFiles = await PermissionService.hasAllFilesAccess();
          selected =
              await UserDataLocationService.resolveAndroidUserDataPath(
                uri.toString(),
                hasAllFilesAccess: hasFiles,
              ) ??
              UserDataLocationService.safUriToRealPath(uri.toString());
        }
      }

      if (selected == null || !mounted) return;
      selected = selected.replaceFirst(RegExp(r'[\\/]+$'), '');
      if (!Directory(selected).existsSync()) {
        if (mounted) {
          custom.AppNotification.showNotification(
            context,
            AppLocale.customSaveFolderInvalid.getString(context),
            type: custom.NotificationType.error,
          );
        }
        return;
      }

      await NeoSyncSaveFolderRepository.saveFolder(
        system,
        emulatorSlug,
        selected,
      );
      await _loadConfigured();

      if (!mounted) return;
      final provider = context.read<NeoSyncProvider>();
      if (mounted) setState(() => _syncing = true);
      try {
        await provider.syncCustomSaveFolder(system, emulatorSlug);
      } finally {
        if (mounted) setState(() => _syncing = false);
      }
    } catch (e, st) {
      _log.e(
        'CustomSaveFolder: error in _selectFolderFor',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        custom.AppNotification.showNotification(
          context,
          '$e',
          type: custom.NotificationType.error,
        );
      }
    }
  }

  Future<void> _removeFolder(String system, String emulatorSlug) async {
    await NeoSyncSaveFolderRepository.removeFolder(system, emulatorSlug);
    await _loadConfigured();
  }

  Future<void> _syncFolder(String system, String emulatorSlug) async {
    if (_syncing) return;
    if (mounted) setState(() => _syncing = true);
    try {
      await context.read<NeoSyncProvider>().syncCustomSaveFolder(
        system,
        emulatorSlug,
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openConfigDialog() async {
    _gamepadNav.deactivate();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CustomSaveFoldersDialog(
        systems: _systems,
        isSyncing: _syncing,
        onSelectFolder: (system, slug) => _selectFolderFor(system, slug),
        onSyncFolder: (system, slug) => _syncFolder(system, slug),
        onRemoveFolder: (system, slug) => _removeFolder(system, slug),
        onChanged: _loadConfigured,
      ),
    );
    _gamepadNav.activate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _syncing;

    return Padding(
      padding: EdgeInsets.only(top: 52.r, left: 8.r, right: 8.r, bottom: 8.r),
      child: Column(
        children: [
          NeoSyncSectionHeader(
            icon: Symbols.folder_special_rounded,
            title: AppLocale.customSaveFoldersTitle.getString(context),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 2.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${_configured.length} configured',
                style: TextStyle(
                  fontSize: 8.r,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondary,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.r),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1.r,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Configure a new folder
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : _openConfigDialog,
                        icon: busy
                            ? SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.r,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Icon(Symbols.add_rounded, size: 18.r),
                        label: Text(
                          AppLocale.customSaveFolderConfigure.getString(context),
                          style: TextStyle(fontSize: 11.r),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: 10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.r),
                    Divider(height: 1.r),
                    SizedBox(height: 8.r),
                    Text(
                      AppLocale.customSaveFolderConfiguredList.getString(context),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.r,
                      ),
                    ),
                    SizedBox(height: 6.r),
                    if (_configured.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Symbols.folder_special_rounded,
                                size: 40.r,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              SizedBox(height: 8.r),
                              Text(
                                'No custom folders configured',
                                style: TextStyle(
                                  fontSize: 12.r,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final (system, slug, path) in _configured)
                        Padding(
                          padding: EdgeInsets.only(bottom: 6.r),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                width: 1.r,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$system / $slug',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10.r,
                                            ),
                                      ),
                                      SizedBox(height: 2.r),
                                      Text(
                                        path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 9.r,
                                              fontFamily: 'monospace',
                                              color: theme
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Symbols.sync_rounded, size: 16.r),
                                  tooltip: AppLocale.customSaveFolderSync.getString(context),
                                  onPressed: busy
                                      ? null
                                      : () => _syncFolder(system, slug),
                                ),
                                IconButton(
                                  icon: Icon(Symbols.delete_rounded, size: 16.r),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          await _removeFolder(system, slug);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 6.r),
          Align(
            alignment: Alignment.centerRight,
            child: NeoSyncBackButton(onTap: () => widget.onBack()),
          ),
        ],
      ),
    );
  }
}
