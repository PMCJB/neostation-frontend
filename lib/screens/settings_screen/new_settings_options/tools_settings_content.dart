import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/providers/file_provider.dart';
import 'package:neostation/providers/sqlite_config_provider.dart';
import 'package:neostation/repositories/config_repository.dart';
import 'package:neostation/repositories/system_repository.dart';
import 'package:neostation/services/logger_service.dart';
import 'package:neostation/services/global_notification_service.dart';
import 'package:neostation/services/metadata_cleanup_service.dart';
import 'package:neostation/services/rom_folder_organizer_service.dart';
import 'package:neostation/widgets/confirm_action_dialog.dart';
import 'package:neostation/widgets/custom_notification.dart';
import 'settings_title.dart';
import 'widgets/settings_card_row.dart';
import 'widgets/settings_action_button.dart';

class ToolsSettingsContent extends StatefulWidget {
  final bool isContentFocused;
  final int selectedContentIndex;

  const ToolsSettingsContent({
    super.key,
    required this.isContentFocused,
    required this.selectedContentIndex,
  });

  @override
  State<ToolsSettingsContent> createState() => ToolsSettingsContentState();
}

class ToolsSettingsContentState extends State<ToolsSettingsContent> {
  static final _log = LoggerService.instance;
  bool _isOrganizingMultiDisc = false;
  bool _isCleaningMetadata = false;
  List<String> _currentRomFolders = [];

  @override
  void initState() {
    super.initState();
    _loadRomFolders();
  }

  Future<void> _loadRomFolders() async {
    try {
      _currentRomFolders = await ConfigRepository.getUserRomFolders();
      if (mounted) setState(() {});
    } catch (e) {
      _log.e('Failed to load ROM folders for tools: $e');
    }
  }

  int getItemCount() => 2;

  void scrollToIndex(int index) {}

  void selectItem(int index) {
    switch (index) {
      case 0:
        _organizeMultiDiscGames();
      case 1:
        _cleanOrphanedMetadata();
    }
  }

  Future<void> _organizeMultiDiscGames() async {
    if (_isOrganizingMultiDisc) return;

    if (_currentRomFolders.isEmpty) {
      if (mounted) {
        AppNotification.showNotification(
          context,
          AppLocale.organizeMultiDiscNoRomFoldersConfigured.getString(context),
          type: NotificationType.info,
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocale.organizeMultiDiscGames.getString(context)),
        content: Text(AppLocale.organizeMultiDiscWarning.getString(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocale.cancel.getString(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocale.confirm.getString(context)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final multiDiscSystems = (await SystemRepository.getAllSystems())
        .where((system) => system.multiDisc)
        .toList();
    final supportedFolders = multiDiscSystems
        .expand((system) => [system.folderName, ...system.folders])
        .where((folder) => folder.isNotEmpty)
        .toSet();

    setState(() => _isOrganizingMultiDisc = true);
    if (mounted) {
      AppNotification.showNotification(
        context,
        AppLocale.organizeMultiDiscScanning.getString(context),
        type: NotificationType.info,
        duration: const Duration(minutes: 5),
        notificationId: 'organize_multidisc',
        progress: 0,
      );
    }

    String? completionMessage;
    NotificationType? completionType;
    try {
      final result = await RomFolderOrganizerService.organizeRomFolders(
        _currentRomFolders,
        supportedSystemFolders: supportedFolders,
        onProgress: (completed, total) {
          if (!mounted || total == 0) return;
          AppNotification.showNotification(
            context,
            AppLocale.organizeMultiDiscScanning.getString(context),
            type: NotificationType.info,
            notificationId: 'organize_multidisc',
            progress: completed / total,
          );
        },
      );

      if (result.hasChanges && mounted) {
        final configProvider = Provider.of<SqliteConfigProvider>(
          context,
          listen: false,
        );
        for (final system in multiDiscSystems) {
          await configProvider.rescanSystemSilent(system);
        }
      }

      if (mounted) {
        final skippedNote = result.rootsSkipped > 0
            ? AppLocale.organizeMultiDiscSkippedSuffix
                  .getString(context)
                  .replaceFirst('{count}', result.rootsSkipped.toString())
            : '';
        completionMessage = result.hasChanges
            ? AppLocale.organizeMultiDiscDone
                  .getString(context)
                  .replaceFirst('{groups}', result.groupsOrganized.toString())
                  .replaceFirst('{files}', result.filesMoved.toString())
                  .replaceFirst(
                    '{playlists}',
                    result.playlistsCreated.toString(),
                  )
                  .replaceFirst('{skipped}', skippedNote)
            : AppLocale.organizeMultiDiscNoSetsFound
                  .getString(context)
                  .replaceFirst('{skipped}', skippedNote);
        completionType = result.hasChanges
            ? NotificationType.success
            : NotificationType.info;
      }
    } catch (e) {
      _log.e('Failed to organize multi-disc games: $e');
      if (mounted) {
        completionMessage = AppLocale.organizeMultiDiscFailed
            .getString(context)
            .replaceFirst('{error}', e.toString());
        completionType = NotificationType.error;
      }
    } finally {
      if (mounted) {
        setState(() => _isOrganizingMultiDisc = false);
        await _loadRomFolders();
        if (completionMessage != null && completionType != null && mounted) {
          AppNotification.showNotification(
            context,
            completionMessage,
            type: completionType,
            duration: const Duration(seconds: 10),
          );
        }
      }
    }
  }

  Future<void> _cleanOrphanedMetadata() async {
    if (_isCleaningMetadata) return;

    final locale = AppLocale.cleanOrphanedMetadata.getString(context);
    final localeWarning = AppLocale.cleanOrphanedMetadataWarning.getString(context);
    final localeNothingFound = AppLocale.cleanOrphanedMetadataNothingFound.getString(context);
    final localeScanning = AppLocale.cleanOrphanedMetadataScanning.getString(context);
    final localeCleaningItem = AppLocale.cleanOrphanedMetadataCleaningItem.getString(context);
    final localeDelete = AppLocale.delete.getString(context);
    final localeFailed = AppLocale.cleanOrphanedMetadataFailed.getString(context);
    final localeDone = AppLocale.cleanOrphanedMetadataDone.getString(context);
    final localeEsdeSkipped = AppLocale.cleanOrphanedMetadataEsdeSkippedSuffix.getString(context);

    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    if (!fileProvider.isInitialized) {
      if (mounted) {
        AppNotification.showNotification(
          context,
          localeFailed.replaceFirst(
            '{error}',
            'File provider not initialized',
          ),
          type: NotificationType.error,
        );
      }
      return;
    }

    // Analyze without deleting so the user can review what will be affected.
    final analysis = await MetadataCleanupService.analyze();
    if (!mounted) return;

    if (!analysis.hasOrphans) {
      AppNotification.showNotification(
        context,
        localeNothingFound,
        type: NotificationType.info,
      );
      return;
    }

    final neoStationCount = analysis.orphanedItems.where((i) => i.isNeoStation).length;
    final esdeCount = analysis.orphanedItems.where((i) => i.esdeImported).length;

    final body = StringBuffer()
      ..writeln(localeWarning)
      ..writeln()
      ..writeln(
        'Found ${analysis.orphanedItems.length} orphaned metadata entr${analysis.orphanedItems.length == 1 ? 'y' : 'ies'}. '
            '$neoStationCount will be deleted from the database and disk.',
      );
    if (esdeCount > 0) {
      body.writeln(
        '$esdeCount ES-DE imported entr${esdeCount == 1 ? 'y' : 'ies'} will be left untouched.',
      );
    }

    final accentColor = Theme.of(context).colorScheme.error;
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: locale,
      body: body.toString().trim(),
      confirmLabel: localeDelete,
      icon: Symbols.cleaning_services_rounded,
      accentColor: accentColor,
    );
    if (confirmed != true || !mounted) return;

    String? completionMessage;
    NotificationType? completionType;
    const notificationId = 'clean_orphaned_metadata';

    try {
      if (mounted) setState(() => _isCleaningMetadata = true);

      // Use the global notification service so the progress bar survives tab
      // and menu navigation while the cleanup runs.
      GlobalNotificationService().show(
        id: notificationId,
        message: localeScanning,
        type: GlobalNotificationType.info,
        duration: const Duration(minutes: 5),
        progress: 0,
        autoDismiss: false,
      );

      final result = await MetadataCleanupService.clean(
        fileProvider: fileProvider,
        onProgress: (progress, currentItem) {
          GlobalNotificationService().update(
            id: notificationId,
            message: localeCleaningItem.replaceFirst(
              '{filename}',
              currentItem.filename,
            ),
            type: GlobalNotificationType.info,
            progress: progress,
            autoDismiss: false,
          );
        },
      );

      if (mounted) {
        final esdeSkippedNote = result.skippedEsdeItems.isNotEmpty
            ? localeEsdeSkipped.replaceFirst(
                '{count}',
                result.skippedEsdeItems.length.toString(),
              )
            : '';
        if (result.hasDeletions) {
          completionMessage = localeDone
                  .replaceFirst('{entries}', result.deletedItems.length.toString())
                  .replaceFirst('{files}', result.deletedMediaFiles.toString()) +
              esdeSkippedNote;
          completionType = NotificationType.success;
        } else {
          completionMessage = localeNothingFound + esdeSkippedNote;
          completionType = NotificationType.info;
        }
      }
    } catch (e, stackTrace) {
      _log.e('Failed to clean orphaned metadata: $e', stackTrace: stackTrace);
      if (mounted) {
        completionMessage = localeFailed.replaceFirst('{error}', e.toString());
        completionType = NotificationType.error;
      }
    } finally {
      if (mounted) {
        setState(() => _isCleaningMetadata = false);
        if (completionMessage != null && completionType != null) {
          final globalType = completionType == NotificationType.success
              ? GlobalNotificationType.success
              : GlobalNotificationType.error;
          GlobalNotificationService().update(
            id: notificationId,
            message: completionMessage,
            type: globalType,
            progress: null,
            autoDismiss: true,
            duration: const Duration(seconds: 10),
          );
        }
      } else {
        // Make sure the persistent notification is removed if the widget that
        // started the operation is no longer in the tree.
        GlobalNotificationService().dismiss(notificationId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected =
        widget.isContentFocused && widget.selectedContentIndex == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTitle(
          title: AppLocale.tools.getString(context),
          subtitle: AppLocale.toolsSubtitle.getString(context),
        ),
        SizedBox(height: 12.r),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              SettingsCardRow(
                icon: Symbols.folder_managed_rounded,
                title: AppLocale.organizeMultiDiscGames.getString(context),
                subtitle: AppLocale.organizeMultiDiscGamesSubtitle.getString(
                  context,
                ),
                subtitleMaxLines: 2,
                selected: isSelected,
                onTap: () => _organizeMultiDiscGames(),
                trailing: SettingsActionButton(
                  icon: Symbols.folder_managed_rounded,
                  selected: isSelected,
                ),
              ),
              SettingsCardRow(
                icon: Symbols.cleaning_services_rounded,
                title: AppLocale.cleanOrphanedMetadata.getString(context),
                subtitle: AppLocale.cleanOrphanedMetadataSubtitle.getString(
                  context,
                ),
                subtitleMaxLines: 2,
                selected: widget.isContentFocused && widget.selectedContentIndex == 1,
                onTap: () => _cleanOrphanedMetadata(),
                trailing: SettingsActionButton(
                  icon: Symbols.cleaning_services_rounded,
                  selected: widget.isContentFocused && widget.selectedContentIndex == 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
