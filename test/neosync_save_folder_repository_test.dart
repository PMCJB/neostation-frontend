import 'package:flutter_test/flutter_test.dart';
import 'package:neostation/data/datasources/sqlite_service.dart';
import 'package:neostation/repositories/neosync_save_folder_repository.dart';
import 'package:neostation/utils/cloud_path_builder.dart';

import 'database_test_helper.dart';

void main() {
  group('NeoSync custom save folders', () {
    final dbHelper = DatabaseTestHelper();

    setUp(() async => dbHelper.setUp());
    tearDown(() async => dbHelper.tearDown());

    test('returns null when no folder is configured', () async {
      final folder = await NeoSyncSaveFolderRepository.getFolder(
        'ps2',
        'armsx2',
      );
      expect(folder, isNull);
    });

    test('persists and reads back a configured folder', () async {
      await NeoSyncSaveFolderRepository.saveFolder(
        'ps2',
        'armsx2',
        '/storage/emulated/0/ARMSX2',
      );

      final folder = await NeoSyncSaveFolderRepository.getFolder(
        'ps2',
        'armsx2',
      );
      expect(folder, '/storage/emulated/0/ARMSX2');
    });

    test('upserts on repeated saves for the same system + emulator', () async {
      await NeoSyncSaveFolderRepository.saveFolder('ps2', 'armsx2', '/old');
      await NeoSyncSaveFolderRepository.saveFolder('ps2', 'armsx2', '/new');

      final folder = await NeoSyncSaveFolderRepository.getFolder(
        'ps2',
        'armsx2',
      );
      expect(folder, '/new');
    });

    test('keeps separate folders for different emulators', () async {
      await NeoSyncSaveFolderRepository.saveFolder('ps2', 'armsx2', '/a');
      await NeoSyncSaveFolderRepository.saveFolder('ps2', 'duckstation', '/b');

      final folders = await NeoSyncSaveFolderRepository.getFoldersForSystem(
        'ps2',
      );
      expect(folders, {'armsx2': '/a', 'duckstation': '/b'});
    });

    test('removes a configured folder', () async {
      await NeoSyncSaveFolderRepository.saveFolder('ps2', 'armsx2', '/a');
      await NeoSyncSaveFolderRepository.removeFolder('ps2', 'armsx2');

      final folder = await NeoSyncSaveFolderRepository.getFolder(
        'ps2',
        'armsx2',
      );
      expect(folder, isNull);
    });
  });

  group('NeoSync core folder resolution', () {
    final dbHelper = DatabaseTestHelper();

    setUp(() async => dbHelper.setUp());
    tearDown(() async => dbHelper.tearDown());

    test('findCoreFolderByNeosyncSlug returns core_filename', () async {
      final db = await SqliteService.getDatabase();
      await db.insert('app_emulators', {
        'system_id': 'snes',
        'os_id': 1,
        'name': 'RetroArch64 Snes9x',
        'unique_identifier': 'snes.ra64.snes9x',
        'is_standalone': 0,
        'core_filename': 'snes9x',
        'neosync_slug': 'retroarch.snes9x',
      });

      final folder = await SqliteService.findCoreFolderByNeosyncSlug(
        'retroarch.snes9x',
      );
      expect(folder, 'snes9x');
    });

    test('findCoreFolderByNeosyncSlug returns null when slug is unknown', () async {
      final folder = await SqliteService.findCoreFolderByNeosyncSlug(
        'retroarch.unknown',
      );
      expect(folder, isNull);
    });

    test('findCoreFolderByNeosyncSlug ignores rows without core_filename', () async {
      final db = await SqliteService.getDatabase();
      await db.insert('app_emulators', {
        'system_id': 'gba',
        'os_id': 1,
        'name': 'RetroArch64 mGBA',
        'unique_identifier': 'gba.ra64.mgba',
        'is_standalone': 0,
        'core_filename': null,
        'neosync_slug': 'retroarch.mgba',
      });

      final folder = await SqliteService.findCoreFolderByNeosyncSlug(
        'retroarch.mgba',
      );
      expect(folder, isNull);
    });
  });

  group('CloudPathBuilder', () {
    test('builds a shared memcard path under the v2 namespace', () {
      final p = CloudPathBuilder.build(
        system: 'ps2',
        emulatorSlug: 'armsx2',
        scope: 'shared',
        filePath: 'Mcd001.ps2',
      );
      expect(p, 'v2/saves/ps2/armsx2/shared/Mcd001.ps2');
    });

    test('builds a per-game save path under the v2 namespace', () {
      final p = CloudPathBuilder.build(
        system: 'ps1',
        emulatorSlug: 'duckstation',
        scope: 'game',
        filePath: 'Street Fighter Alpha 3 (USA).srm',
        gameName: 'Street Fighter Alpha 3 (USA)',
      );
      expect(
        p,
        'v2/saves/ps1/duckstation/game/Street Fighter Alpha 3 (USA)/Street Fighter Alpha 3 (USA).srm',
      );
    });

    test('builds a state path under the v2 namespace', () {
      final p = CloudPathBuilder.build(
        system: 'ps1',
        emulatorSlug: 'retroarch.beetle-psx-hw',
        scope: 'game',
        filePath: 'Street Fighter Alpha 3 (USA).state',
        gameName: 'Street Fighter Alpha 3 (USA)',
        isState: true,
      );
      expect(
        p,
        'v2/states/ps1/retroarch.beetle-psx-hw/game/Street Fighter Alpha 3 (USA)/Street Fighter Alpha 3 (USA).state',
      );
    });

    test('parses a standard v2 path', () {
      final parsed = CloudPathBuilder.parse(
        'v2/saves/ps2/armsx2/shared/Mcd001.ps2',
      );
      expect(parsed, isNotNull);
      expect(parsed!.system, 'ps2');
      expect(parsed.emulatorSlug, 'armsx2');
      expect(parsed.scope, 'shared');
      expect(parsed.isShared, isTrue);
      expect(parsed.filePath, 'Mcd001.ps2');
    });

    test('treats legacy paths as legacy', () {
      expect(CloudPathBuilder.isLegacy('saves/PS2/Mcd001.ps2'), isTrue);
      expect(
        CloudPathBuilder.isLegacy('saves/Beetle PSX HW/Game.srm'),
        isTrue,
      );
      expect(CloudPathBuilder.isLegacy('v2/saves/ps2/armsx2/shared/a.ps2'), isFalse);
    });

    test('does not parse legacy paths as v2', () {
      expect(
        CloudPathBuilder.parse('saves/PS2/Mcd001.ps2'),
        isNull,
      );
    });

    test('derives RetroArch slug from unique id', () {
      expect(
        CloudPathBuilder.slugFromEmulatorUniqueId('ps2.ra.pcsx2'),
        'retroarch.pcsx2',
      );
      expect(
        CloudPathBuilder.slugFromEmulatorUniqueId('ps1.ra64.mednafen_psx_hw'),
        'retroarch.mednafen-psx-hw',
      );
      expect(
        CloudPathBuilder.slugFromEmulatorUniqueId('ps2.come.nanodata.armsx2'),
        'armsx2',
      );
    });
  });
}
