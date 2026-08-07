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

/// Panel that lets the user configure a custom save folder for a specific
/// system + emulator (ARMSX2, ARMSX1, DuckStation, etc.).
class CustomSaveFoldersPanel extends StatefulWidget {
  const CustomSaveFoldersPanel({super.key});

  @override
  State<CustomSaveFoldersPanel> createState() => _CustomSaveFoldersPanelState();
}

class _CustomSaveFoldersPanelState extends State<CustomSaveFoldersPanel> {
  bool _expanded = false;
  bool _configuring = false;
  List<SystemModel> _systems = [];
  String? _selectedSystem;
  List<CoreEmulatorModel> _emulators = [];
  String? _selectedEmulatorUniqueId;
  List<(String, String, String)> _configured = [];
  bool _syncingFolder = false;

  @override
  void initState() {
    super.initState();
    _loadSystems();
  }

  Future<void> _loadSystems() async {
    try {
      final systems = await SystemRepository.getAllSystems();
      final withEmulators = systems
          .where((s) => s.neosync.sync || s.folderName.isNotEmpty)
          .toList();
      if (mounted) setState(() => _systems = withEmulators);
      await _loadConfigured();
    } catch (e) {
      // Non-fatal: panel stays hidden/empty if systems cannot be loaded.
    }
  }

  Future<void> _loadConfigured() async {
    try {
      final configured =
          await NeoSyncSaveFolderRepository.getAllEntries();
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
      final system = _systems.firstWhere(
        (s) => s.folderName == folderName,
        orElse: () => _systems.first,
      );
      final emulators = await SqliteService.getEmulatorsForSystemCurrentOs(
        system.id ?? system.folderName,
      );
      // Custom folders target standalone emulators (ARMSX2, DuckStation, ...).
      // RetroArch cores are discovered automatically from their saves dir, so
      // they are not offered here.
      final standalone = emulators.where((e) => e.isStandalone).toList();
      if (mounted) {
        setState(() => _emulators = standalone);
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NeoSyncProvider>();
    final isBusy = _configuring || provider.isSyncing || _syncingFolder;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.folder_special_rounded,
                size: 16.r,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 4.r),
              Expanded(
                child: Text(
                  AppLocale.customSaveFoldersTitle.getString(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.r,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded
                      ? Symbols.keyboard_arrow_up_rounded
                      : Symbols.keyboard_arrow_down_rounded,
                  size: 18.r,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (_expanded) ...[
            SizedBox(height: 6.r),
            if (_systems.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedSystem,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.r,
                    vertical: 6.r,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                style: TextStyle(fontSize: 9.r),
                hint: Text(
                  AppLocale.customSaveFolderPickSystem.getString(context),
                  style: TextStyle(fontSize: 9.r),
                ),
                items: _systems
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.folderName,
                        child: Text(
                          '${s.realName} (${s.folderName})',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.r),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onSystemSelected,
              ),
              SizedBox(height: 6.r),
              DropdownButtonFormField<String>(
                initialValue: _selectedEmulatorUniqueId,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.r,
                    vertical: 6.r,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                style: TextStyle(fontSize: 9.r),
                hint: Text(
                  AppLocale.customSaveFolderPickEmulator.getString(context),
                  style: TextStyle(fontSize: 9.r),
                ),
                items: _emulators
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.uniqueId,
                        child: Text(
                          e.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.r),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedEmulatorUniqueId = v),
              ),
              SizedBox(height: 6.r),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy || _selectedEmulatorSlug == null
                      ? null
                      : _selectFolder,
                  icon: Icon(Symbols.folder_open_rounded, size: 14.r),
                  label: Text(
                    AppLocale.customSaveFolderSelect.getString(context),
                    style: TextStyle(fontSize: 9.r),
                  ),
                ),
              ),
            ],
            if (_configured.isNotEmpty) ...[
              SizedBox(height: 6.r),
              for (final (system, slug, path) in _configured)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.r),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$system / $slug: $path',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 8.r,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Symbols.delete_rounded, size: 14.r),
                        onPressed: isBusy
                            ? null
                            : () => _removeFolder(system, slug),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
