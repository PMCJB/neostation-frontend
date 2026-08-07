import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/models/system_model.dart';
import 'package:neostation/providers/neo_sync_provider.dart';
import 'package:neostation/repositories/neosync_save_folder_repository.dart';
import 'package:neostation/repositories/system_repository.dart';
import 'package:neostation/services/permission_service.dart';
import 'package:neostation/services/user_data_location_service.dart';
import 'package:neostation/widgets/custom_notification.dart' as custom;
import 'package:neostation/widgets/tv_directory_picker.dart';
import 'package:provider/provider.dart';
import 'package:neostation/data/datasources/sqlite_service.dart';
import 'package:neostation/models/core_emulator_model.dart';
import 'package:neostation/utils/cloud_path_builder.dart';

/// Compact card that opens a dialog for configuring custom save folders.
///
/// The dialog lets the user pick a system + standalone emulator and select the
/// folder where that emulator keeps its saves (ARMSX2, ARMSX1, DuckStation,
/// etc.). It scrolls so every control fits, and works with both touch and
/// gamepad navigation.
class CustomSaveFoldersPanel extends StatefulWidget {
  const CustomSaveFoldersPanel({super.key});

  @override
  State<CustomSaveFoldersPanel> createState() => _CustomSaveFoldersPanelState();
}

class _CustomSaveFoldersPanelState extends State<CustomSaveFoldersPanel> {
  List<SystemModel> _systems = [];
  List<(String, String, String)> _configured = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  void _openDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => CustomSaveFoldersDialog(
        systems: _systems,
        onChanged: _loadConfigured,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.r,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.folder_special_rounded,
            size: 16.r,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: 8.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocale.customSaveFoldersTitle.getString(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.r,
                  ),
                ),
                SizedBox(height: 2.r),
                Text(
                  '${_configured.length} configured',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 8.r,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.r),
          OutlinedButton.icon(
            onPressed: _openDialog,
            icon: Icon(Symbols.tune_rounded, size: 14.r),
            label: Text(
              AppLocale.customSaveFolderConfigure.getString(context),
              style: TextStyle(fontSize: 9.r),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog that configures custom save folders for a system + emulator.
class CustomSaveFoldersDialog extends StatefulWidget {
  final List<SystemModel> systems;
  final VoidCallback onChanged;

  const CustomSaveFoldersDialog({
    super.key,
    required this.systems,
    required this.onChanged,
  });

  @override
  State<CustomSaveFoldersDialog> createState() => _CustomSaveFoldersDialogState();
}

class _CustomSaveFoldersDialogState extends State<CustomSaveFoldersDialog> {
  String? _selectedSystem;
  List<CoreEmulatorModel> _emulators = [];
  String? _selectedEmulatorUniqueId;
  List<(String, String, String)> _configured = [];
  bool _configuring = false;
  bool _syncingFolder = false;

  @override
  void initState() {
    super.initState();
    _loadConfigured();
  }

  Future<void> _loadConfigured() async {
    try {
      final configured = await NeoSyncSaveFolderRepository.getAllEntries();
      if (mounted) setState(() => _configured = configured);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _onSystemSelected(String? folderName) async {
    setState(() {
      _selectedSystem = folderName;
      _emulators = [];
      _selectedEmulatorUniqueId = null;
    });
    if (folderName == null) return;

    try {
      final system = widget.systems.firstWhere(
        (s) => s.folderName == folderName,
        orElse: () => widget.systems.first,
      );
      final emulators = await SqliteService.getEmulatorsForSystemCurrentOs(
        system.id ?? system.folderName,
      );
      // Custom folders target standalone emulators (ARMSX2, DuckStation, ...).
      // RetroArch cores are discovered automatically from their saves dir, so
      // they are not offered here.
      final standalone = emulators.where((e) => e.isStandalone).toList();
      if (mounted) setState(() => _emulators = standalone);
    } catch (e) {
      // ignore
    }
  }

  String? get _selectedEmulatorSlug {
    if (_selectedEmulatorUniqueId == null) return null;
    return CloudPathBuilder.slugFromEmulatorUniqueId(_selectedEmulatorUniqueId!);
  }

  Future<void> _selectFolder() async {
    final system = _selectedSystem;
    final emulatorSlug = _selectedEmulatorSlug;
    if (system == null || emulatorSlug == null || _configuring) return;
    setState(() => _configuring = true);

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
        custom.AppNotification.showNotification(
          context,
          AppLocale.customSaveFolderInvalid.getString(context),
          type: custom.NotificationType.error,
        );
        return;
      }

      await NeoSyncSaveFolderRepository.saveFolder(
        system,
        emulatorSlug,
        selected,
      );
      if (!mounted) return;
      await _loadConfigured();
      widget.onChanged();
      if (!mounted) return;

      // Upload the folder's existing saves right away so they are backed up
      // immediately instead of waiting for the next global auto-sync.
      setState(() => _syncingFolder = true);
      try {
        await context.read<NeoSyncProvider>().syncCustomSaveFolder(
          system,
          emulatorSlug,
        );
      } finally {
        if (mounted) setState(() => _syncingFolder = false);
      }
    } catch (e) {
      if (mounted) {
        custom.AppNotification.showNotification(
          context,
          '$e',
          type: custom.NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _configuring = false);
    }
  }

  Future<void> _removeFolder(String system, String emulatorSlug) async {
    await NeoSyncSaveFolderRepository.removeFolder(system, emulatorSlug);
    await _loadConfigured();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NeoSyncProvider>();
    final isBusy = _configuring || provider.isSyncing || _syncingFolder;

    final selectDecoration = InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
    );
    final selectStyle = TextStyle(fontSize: 12.r);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Symbols.folder_special_rounded,
            size: 18.r,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(
              AppLocale.customSaveFoldersTitle.getString(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13.r,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340.r,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedSystem,
                decoration: selectDecoration,
                style: selectStyle,
                hint: Text(
                  AppLocale.customSaveFolderPickSystem.getString(context),
                  style: selectStyle,
                ),
                items: widget.systems
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.folderName,
                        child: Text(
                          '${s.realName} (${s.folderName})',
                          overflow: TextOverflow.ellipsis,
                          style: selectStyle,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onSystemSelected,
              ),
              SizedBox(height: 8.r),
              DropdownButtonFormField<String>(
                initialValue: _selectedEmulatorUniqueId,
                decoration: selectDecoration,
                style: selectStyle,
                hint: Text(
                  AppLocale.customSaveFolderPickEmulator.getString(context),
                  style: selectStyle,
                ),
                items: _emulators
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.uniqueId,
                        child: Text(
                          e.name,
                          overflow: TextOverflow.ellipsis,
                          style: selectStyle,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedEmulatorUniqueId = v),
              ),
              SizedBox(height: 10.r),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy || _selectedEmulatorSlug == null
                      ? null
                      : _selectFolder,
                  icon: _syncingFolder
                      ? SizedBox(
                          width: 14.r,
                          height: 14.r,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Symbols.folder_open_rounded, size: 14.r),
                  label: Text(
                    AppLocale.customSaveFolderSelect.getString(context),
                    style: TextStyle(fontSize: 11.r),
                  ),
                ),
              ),
              if (_configured.isNotEmpty) ...[
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
                for (final (system, slug, path) in _configured)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.r),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$system / $slug: $path',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.r,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Symbols.delete_rounded, size: 16.r),
                          onPressed: isBusy
                              ? null
                              : () => _removeFolder(system, slug),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.close.getString(context),
            style: TextStyle(fontSize: 11.r),
          ),
        ),
      ],
    );
  }
}
