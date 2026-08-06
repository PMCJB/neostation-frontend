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

/// Panel that lets the user configure a custom save folder for any system +
/// emulator (ARMSX2, ARMSX1, DuckStation, etc.) and migrate legacy cloud paths
/// to the NeoSync v2 standard.
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
  Map<String, String> _configured = {};
  bool _migrating = false;

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
      final configured = await NeoSyncSaveFolderRepository.getAllFolders();
      if (mounted) setState(() => _configured = configured);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _selectFolder() async {
    final system = _selectedSystem;
    if (system == null || _configuring) return;
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
        'unknown',
        selected,
      );
      if (!mounted) return;
      await _loadConfigured();
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

  Future<void> _removeFolder(String system) async {
    await NeoSyncSaveFolderRepository.removeFolder(system, 'unknown');
    await _loadConfigured();
  }

  Future<void> _migrate() async {
    if (_migrating) return;
    setState(() => _migrating = true);
    try {
      final provider = context.read<NeoSyncProvider>();
      await provider.migrateCloudToV2();
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NeoSyncProvider>();
    final isBusy = _configuring || provider.isSyncing;

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
                onChanged: (v) => setState(() => _selectedSystem = v),
              ),
              SizedBox(height: 6.r),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : _selectFolder,
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
              for (final entry in _configured.entries)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.r),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.key}: ${entry.value}',
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
                            : () => _removeFolder(entry.key),
                      ),
                    ],
                  ),
                ),
            ],
            Divider(height: 10.r),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _migrating ? null : _migrate,
                icon: _migrating
                    ? SizedBox(
                        width: 14.r,
                        height: 14.r,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Symbols.auto_awesome_rounded, size: 14.r),
                label: Text(
                  AppLocale.customSaveFoldersMigrate.getString(context),
                  style: TextStyle(fontSize: 9.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
