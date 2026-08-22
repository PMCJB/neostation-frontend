import 'package:flutter_test/flutter_test.dart';
import 'package:neostation/services/global_notification_service.dart';
import 'package:neostation/services/ra_library_match_runner.dart';

import 'database_test_helper.dart';

/// Placeholder copy: these tests care about *whether* the runner speaks, not
/// what it says, so the strings only have to be distinguishable.
const _strings = RaMatchStrings(
  title: 'ra-title',
  lookingUp: 'looking-up',
  hashing: 'hashing {filename}',
  done: 'done {matched}/{hashed}',
  nothingToDo: 'nothing-to-do',
  paused: 'paused {matched}',
  failed: 'failed {error}',
);

GlobalNotificationData? _raNotification() {
  final all = GlobalNotificationService().notifier.value;
  for (final n in all) {
    if (n.id == RaLibraryMatchRunner.notificationId) return n;
  }
  return null;
}

void main() {
  group('an automatic pass that finds nothing stays silent', () {
    final dbHelper = DatabaseTestHelper();
    late dynamic db;

    setUp(() async {
      db = await dbHelper.setUp();
      GlobalNotificationService().dismiss(RaLibraryMatchRunner.notificationId);
      await db.execute(
        "INSERT INTO app_systems (id, real_name, folder_name, ra_id, multidisc)"
        " VALUES ('nes', 'NES', 'nes', '7', 0)",
      );
      // The steady state of a matched library: every ROM already carries a
      // hash, so nothing needs hashing, but the lookup pass still re-walks
      // them all every launch. None of them resolve, because the bundled RA
      // database has no row for them.
      for (var i = 0; i < 3; i++) {
        await db.execute(
          "INSERT INTO user_roms (filename, rom_path, app_system_id, ra_hash) "
          "VALUES ('Game$i.nes', '/roms/nes/Game$i.nes', 'nes', 'hash$i')",
        );
      }
    });

    tearDown(() async {
      GlobalNotificationService().dismiss(RaLibraryMatchRunner.notificationId);
      await dbHelper.tearDown();
    });

    test('posts no notification at all', () async {
      final interrupted = await RaLibraryMatchRunner.run(
        strings: _strings,
        trigger: RaMatchTrigger.automatic,
      );

      expect(interrupted, isFalse);
      expect(
        _raNotification(),
        isNull,
        reason:
            'the lookup pass examines every unmatched ROM on every launch and '
            'legitimately finds nothing; saying so would be noise each time',
      );
    });

    test('the pass the user asked for still answers', () async {
      await RaLibraryMatchRunner.run(
        strings: _strings,
        trigger: RaMatchTrigger.manual,
      );

      expect(
        _raNotification(),
        isNotNull,
        reason: 'they pressed a button, so silence would read as a hang',
      );
    });
  });

  group('an automatic pass that finds something reports it', () {
    final dbHelper = DatabaseTestHelper();
    late dynamic db;

    setUp(() async {
      db = await dbHelper.setUp();
      GlobalNotificationService().dismiss(RaLibraryMatchRunner.notificationId);
      await db.execute(
        "INSERT INTO app_systems (id, real_name, folder_name, ra_id, multidisc)"
        " VALUES ('nes', 'NES', 'nes', '7', 0)",
      );
      await db.execute(
        "INSERT INTO app_ra_game_list (hash, game_id, title, console_id) "
        "VALUES ('hash0', 42, 'Some Game', 7)",
      );
      await db.execute(
        "INSERT INTO user_roms (filename, rom_path, app_system_id, ra_hash) "
        "VALUES ('Game0.nes', '/roms/nes/Game0.nes', 'nes', 'hash0')",
      );
    });

    tearDown(() async {
      GlobalNotificationService().dismiss(RaLibraryMatchRunner.notificationId);
      await dbHelper.tearDown();
    });

    test('a new match is worth a notification', () async {
      await RaLibraryMatchRunner.run(
        strings: _strings,
        trigger: RaMatchTrigger.automatic,
      );

      final note = _raNotification();
      expect(note, isNotNull);
      expect(note!.message, contains('done'));
    });

    test('the notification names the job it is doing', () async {
      await RaLibraryMatchRunner.run(
        strings: _strings,
        trigger: RaMatchTrigger.automatic,
      );

      expect(
        _raNotification()?.title,
        'ra-title',
        reason:
            'the startup pass runs unprompted, so a bare "Identifying '
            'Game.nes" never says what the identifying is for',
      );
    });
  });
}
