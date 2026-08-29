import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:neostation/services/logger_service.dart';
import 'package:neostation/services/sfx_service.dart';

/// Talks to the secondary-display Flutter engine's own native channel
/// (`com.neogamelab.neostation/secondary_apps`, registered by
/// `SecondaryAppsPresentation.kt`). The secondary engine cannot reach the main
/// app's `/game` channel, so the bottom-screen app dock uses this instead to
/// list installed apps, load their icons and launch them (preferring the
/// bottom display, falling back to the top).
///
/// App icons are cached in-process so re-rendering the dock/picker doesn't
/// refetch them across the channel.
class SecondaryAppsService {
  static const MethodChannel _channel = MethodChannel(
    'com.neogamelab.neostation/secondary_apps',
  );

  static final _log = LoggerService.instance;

  /// In-memory icon cache keyed by package name. A null value records a known
  /// "no icon" result so we don't refetch a package that has none.
  static final Map<String, Uint8List?> _iconCache = {};

  /// Lists launchable installed apps as `{name, package}` maps.
  static Future<List<Map<String, dynamic>>> getInstalledApps({
    bool includeSystemApps = false,
  }) async {
    try {
      final List<dynamic> apps = await _channel.invokeMethod(
        'getInstalledApps',
        {'includeSystemApps': includeSystemApps},
      );
      return apps.map((dynamic item) {
        final map = item as Map<Object?, Object?>;
        return map.map((key, value) => MapEntry(key.toString(), value));
      }).toList();
    } on PlatformException catch (e) {
      _log.e("Secondary: failed to get installed apps: '${e.message}'.");
      return [];
    }
  }

  /// Returns the launcher icon (PNG bytes) for [packageName], cached.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    try {
      final Uint8List? iconData = await _channel.invokeMethod('getAppIcon', {
        'packageName': packageName,
      });
      _iconCache[packageName] = iconData;
      return iconData;
    } on PlatformException catch (e) {
      _log.e("Secondary: failed to get app icon: '${e.message}'.");
      return null;
    }
  }

  /// Launches [packageName], preferring the secondary (bottom) display and
  /// falling back to the top display if the OS refuses the targeted launch.
  static Future<bool> launchAppOnSecondary(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('launchAppOnSecondary', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      _log.e("Secondary: failed to launch package: '${e.message}'.");
      return false;
    }
  }

  /// Opens Android's accessibility settings (deep-linked to NeoStation's own
  /// service page) from the secondary-display engine. Used when the Screen
  /// Return service isn't enabled yet — launching an app without it would
  /// strand the user with no way back to Now Playing.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      _log.e(
        "Secondary: failed to open accessibility settings: '${e.message}'.",
      );
    }
  }

  /// Whether the device screen is on, as pushed by the native presentation on
  /// every ACTION_SCREEN_ON/OFF edge.
  static final ValueNotifier<bool> deviceScreenOn = ValueNotifier<bool>(true);

  static bool _screenStateWired = false;

  /// Subscribes to native screen on/off edges and seeds [deviceScreenOn] from
  /// the display's live state. Idempotent — safe to call from every widget that
  /// needs it.
  static void listenForScreenState() {
    if (_screenStateWired) return;
    _screenStateWired = true;

    // Release/reinitialize SoLoud audio engine on the secondary screen when power state toggles
    deviceScreenOn.addListener(() {
      if (!deviceScreenOn.value) {
        if (SoLoud.instance.isInitialized) {
          try {
            SoLoud.instance.deinit();
            SfxService().handleEngineTornDown();
          } catch (_) {}
        }
      } else {
        SfxService().reinitializeAfterEngineRestart();
      }
    });

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeviceScreenOn':
          deviceScreenOn.value = true;
          break;
        case 'onDeviceScreenOff':
          deviceScreenOn.value = false;
          break;
      }
      return null;
    });

    // Edges alone would leave an engine that started while the device was
    // already asleep stuck on the `true` default, so read the display up front.
    unawaited(refreshScreenState());
  }

  /// Re-reads the bottom display's live power state into [deviceScreenOn].
  static Future<void> refreshScreenState() async {
    deviceScreenOn.value = await isDisplayOn();
  }

  /// Asks the native presentation whether the display it renders on is lit.
  static Future<bool> isDisplayOn() async {
    try {
      final bool? on = await _channel.invokeMethod<bool>('isDisplayOn');
      return on ?? true;
    } on PlatformException catch (e) {
      _log.e("Secondary: failed to read display state: '${e.message}'.");
      return true;
    } on MissingPluginException {
      return true;
    }
  }
}
