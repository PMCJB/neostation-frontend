import '../data/datasources/sqlite_service.dart';
import '../models/neo_sync_models.dart';
import '../utils/cloud_path_builder.dart';

/// Represents one legacy cloud file to migrate and its proposed v2 path.
class CloudMigrationItem {
  final NeoSyncFile cloudFile;
  final String legacyPath;
  final String v2Path;

  const CloudMigrationItem({
    required this.cloudFile,
    required this.legacyPath,
    required this.v2Path,
  });
}

/// Maps legacy NeoSync cloud paths to the NeoSync v2 standard.
///
/// The frontend knows the system/emulator mapping (from system JSONs), so it
/// computes the v2 path for every legacy file. The backend then performs the
/// actual rename (GCS copy + metadata update) via `POST /files/migrate`.
class CloudMigrationService {
  CloudMigrationService._();

  /// Computes the v2 path for a legacy cloud path, or null when it cannot be
  /// mapped (e.g. it already follows the v2 layout).
  ///
  /// Supported legacy layouts:
  ///   `saves/<core>/<game>.ext`            (RetroArch per-game saves)
  ///   `states/<core>/<game>.state`         (RetroArch states)
  ///   `saves/PS2/Mcd001.ps2`               (PS2 memcards)
  ///   `saves/NetherSX2/Mcd001.ps2`         (AetherSX2/NetherSX2 memcards)
  ///   `saves/dc/vmu_save_*.bin`            (Dreamcast VMU)
  ///   `saves/custom/<system>/<file>`       (custom folders v1)
  ///
  /// The system is resolved from the core/emulator via the database when
  /// possible; otherwise it falls back to `unknown`.
  static Future<String?> mapLegacyToV2(String legacyPath) async {
    if (legacyPath.startsWith('saves/custom/')) {
      final parts = legacyPath.split('/');
      if (parts.length < 4) return null;
      final system = parts[2];
      final file = parts.sublist(3).join('/');
      return CloudPathBuilder.build(
        system: system,
        emulatorSlug: 'unknown',
        scope: 'shared',
        filePath: file,
      );
    }

    final isState = legacyPath.startsWith('states/');
    final isSave = legacyPath.startsWith('saves/');
    if (!isState && !isSave) return null;

    final body = legacyPath.substring((isState ? 'states/' : 'saves/').length);
    final parts = body.split('/');
    if (parts.isEmpty) return null;

    final fileName = parts.last;
    final firstSegment = parts.first;

    // Determine emulator slug and system.
    final String emulatorSlug;
    final String system;
    if (firstSegment == 'PS2' ||
        firstSegment == 'NetherSX2' ||
        firstSegment == 'dc') {
      // Legacy memcard namespaces carry an emulator/system hint.
      emulatorSlug = firstSegment.toLowerCase() == 'ps2'
          ? 'unknown-ps2'
          : firstSegment.toLowerCase() == 'dc'
          ? 'unknown-dc'
          : 'nethersx2';
      system = firstSegment.toLowerCase() == 'ps2' || firstSegment == 'NetherSX2'
          ? 'ps2'
          : 'dc';
    } else {
      emulatorSlug = CloudPathBuilder.retroArchCoreSlug(firstSegment);
      system = await _systemForCore(firstSegment) ?? 'unknown';
    }

    final isSharedCard = parts.length < 2 ||
        fileName.toLowerCase().endsWith('.ps2') ||
        fileName.toLowerCase().contains('vmu_save');

    final String? gameName;
    if (!isSharedCard) {
      gameName = fileName;
    } else {
      gameName = null;
    }

    return CloudPathBuilder.build(
      system: system,
      emulatorSlug: emulatorSlug,
      scope: isSharedCard ? 'shared' : 'game',
      filePath: fileName,
      gameName: gameName,
      isState: isState,
    );
  }

  /// Returns the system folder name for a RetroArch core display name, or null.
  static Future<String?> _systemForCore(String coreName) async {
    try {
      final rows = await SqliteService.findSystemByCoreName(coreName);
      if (rows == null || rows.isEmpty) return null;
      return rows.first['folder_name']?.toString();
    } catch (e) {
      return null;
    }
  }
}
