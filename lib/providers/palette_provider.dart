import 'package:neostation/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:neostation/themes/app_palettes.dart';
import 'package:neostation/repositories/config_repository.dart';

/// Provider responsible for managing the application's visual palette.
///
/// Supports static palette selection (Dark, Light, OLED, etc.) and a dynamic
/// 'System' mode that automatically synchronizes with the OS platform brightness.
/// Persists the selection to the local database.
class PaletteProvider extends ChangeNotifier with WidgetsBindingObserver {
  static final _log = LoggerService.instance;

  /// The current [ThemeData] being applied to the application.
  ThemeData _currentPalette =
      (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark)
      ? AppPalettes.nsdarkPalette
      : AppPalettes.nslightPalette;

  /// Internal identifier for the current palette. Set to 'system' for dynamic mode.
  String _currentPaletteName = 'system';

  /// Returns the appropriate [ThemeData] for the current selection.
  ///
  /// If in 'system' mode, it dynamically resolves the palette based on the
  /// current platform brightness.
  ThemeData get currentPalette {
    if (_currentPaletteName == 'system') {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark
          ? availablePalettes['nsdark']!
          : availablePalettes['nslight']!;
    }

    return _currentPalette;
  }

  String get currentPaletteName => _currentPaletteName;

  /// Whether the current palette is specifically optimized for OLED displays (pure black).
  bool get isOled => _currentPaletteName == 'oled';

  /// Registry of all available concrete palettes.
  static final Map<String, ThemeData> availablePalettes = {
    'nsdark': AppPalettes.nsdarkPalette,
    'nslight': AppPalettes.nslightPalette,
    'oled': AppPalettes.oledPalette,
    'valentine': AppPalettes.valentinePalette,
    'rgc': AppPalettes.rgcPalette,
    'tw_dark': AppPalettes.twDarkPalette,
    'dracula': AppPalettes.draculaPalette,
    'nord': AppPalettes.nordPalette,
    'gruvbox': AppPalettes.gruvboxPalette,
    'tokyo_night': AppPalettes.tokyoNightPalette,
    'solarized_light': AppPalettes.solarizedLightPalette,
    'one_light': AppPalettes.oneLightPalette,
    'catppuccin': AppPalettes.catppuccinPalette,
    'solarized_dark': AppPalettes.solarizedDarkPalette,
    'palenight': AppPalettes.palenightPalette,
    'horizon': AppPalettes.horizonPalette,
  };

  /// Human-readable mapping for palette identifiers.
  static const Map<String, String> paletteDisplayNames = {
    'system': 'System',
    'nsdark': 'NS Dark',
    'nslight': 'NS Light',
    'oled': 'OLED',
    'valentine': 'Valentine',
    'rgc': 'RGC Light',
    'tw_dark': 'TW Dark',
    'dracula': 'Dracula',
    'nord': 'Nord',
    'gruvbox': 'Gruvbox',
    'tokyo_night': 'Tokyo Night',
    'solarized_light': 'Solarized Light',
    'one_light': 'One Light',
    'catppuccin': 'Catppuccin',
    'solarized_dark': 'Solarized Dark',
    'palenight': 'Palenight',
    'horizon': 'Horizon',
  };

  PaletteProvider() {
    _loadSavedPalette();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Reacts to OS-level brightness changes when in 'system' palette mode.
  @override
  void didChangePlatformBrightness() {
    if (_currentPaletteName == 'system') {
      _log.i('Platform brightness changed, updating system palette...');
      _updateSystemPalette();
      notifyListeners();
    }
  }

  /// Internal logic to resolve the appropriate palette based on system brightness.
  void _updateSystemPalette() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _currentPalette = brightness == Brightness.dark
        ? availablePalettes['nsdark']!
        : availablePalettes['nslight']!;
  }

  /// Loads the persisted palette name from the database and applies it.
  Future<void> _loadSavedPalette() async {
    try {
      final savedPaletteName = await ConfigRepository.getPaletteName();
      if (savedPaletteName == 'system') {
        _currentPaletteName = 'system';
        _updateSystemPalette();
        notifyListeners();
      } else if (availablePalettes.containsKey(savedPaletteName)) {
        _currentPalette = availablePalettes[savedPaletteName]!;
        _currentPaletteName = savedPaletteName;
        notifyListeners();
      } else {
        // The previously selected palette is no longer available (e.g. removed
        // in an update). Fall back to the system palette and persist it.
        _log.w(
          'Saved palette "$savedPaletteName" is no longer available, falling back to system.',
        );
        _currentPaletteName = 'system';
        _updateSystemPalette();
        await ConfigRepository.updatePaletteName('system');
        notifyListeners();
      }
    } catch (e) {
      _log.e('Error loading saved palette: $e');
    }
  }

  /// Updates the application palette and persists the choice to the database.
  ///
  /// Special handling for the 'system' value to enable dynamic mode.
  Future<void> setPalette(String paletteName) async {
    if (paletteName == 'system') {
      _currentPaletteName = 'system';
      _updateSystemPalette();

      try {
        await ConfigRepository.updatePaletteName('system');
      } catch (e) {
        _log.e('Error saving palette: $e');
      }

      notifyListeners();
      return;
    }

    if (availablePalettes.containsKey(paletteName)) {
      _currentPalette = availablePalettes[paletteName]!;
      _currentPaletteName = paletteName;

      try {
        await ConfigRepository.updatePaletteName(paletteName);
      } catch (e) {
        _log.e('Error saving palette: $e');
      }

      notifyListeners();
    }
  }

  /// Returns a metadata list for all available palettes, excluding the 'system' option.
  ///
  /// Used for populating palette selection UIs with display names and preview icons.
  List<Map<String, String>> getPaletteList() {
    return availablePalettes.keys.map((key) {
      return {
        'name': key,
        'displayName': paletteDisplayNames[key] ?? key,
        'logoPath': AppPalettes.getLogoPath(availablePalettes[key]!),
      };
    }).toList();
  }

  /// Resolves the absolute path to the main logo asset for the current palette.
  String getCurrentLogoPath() {
    return AppPalettes.getLogoPathByName(_currentPaletteName);
  }
}
