import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:neostation/providers/palette_provider.dart';

// Import all individual themes
import 'nsdark_palette.dart' as nsdark;
import 'nslight_palette.dart' as nslight;
import 'oled_palette.dart' as oled;
import 'valentine_palette.dart' as valentine;
import 'dracula_palette.dart' as dracula;
import 'nord_palette.dart' as nord;
import 'coffee_palette.dart' as coffee;
import 'tokyo_night_palette.dart' as tokyo_night;
import 'solarized_light_palette.dart' as solarized_light;
import 'one_light_palette.dart' as one_light;
import 'cyberpunk_palette.dart' as cyberpunk;
import 'solarized_dark_palette.dart' as solarized_dark;
import 'palenight_palette.dart' as palenight;
import 'horizon_palette.dart' as horizon;

class AppPalettes {
  static String getLogoPath() {
    return 'assets/images/logo_transparent.png';
  }

  // References to individual themes
  static ThemeData get nsdarkPalette => nsdark.nsdarkPalette;
  static ThemeData get nslightPalette => nslight.nslightPalette;
  static ThemeData get oledPalette => oled.oledPalette;
  static ThemeData get valentinePalette => valentine.valentinePalette;
  static ThemeData get draculaPalette => dracula.draculaPalette;
  static ThemeData get nordPalette => nord.nordPalette;
  static ThemeData get coffeePalette => coffee.coffeePalette;
  static ThemeData get tokyoNightPalette => tokyo_night.tokyoNightPalette;
  static ThemeData get solarizedLightPalette =>
      solarized_light.solarizedLightPalette;
  static ThemeData get oneLightPalette => one_light.oneLightPalette;
  static ThemeData get cyberpunkPalette => cyberpunk.cyberpunkPalette;
  static ThemeData get solarizedDarkPalette =>
      solarized_dark.solarizedDarkPalette;
  static ThemeData get palenightPalette => palenight.palenightPalette;
  static ThemeData get horizonPalette => horizon.horizonPalette;

  // References to custom colors for each theme
  static dynamic get nsdarkCustomColors => nsdark.NSdarkCustomColors();
  static dynamic get nslightCustomColors => nslight.NSlightCustomColors();
  static dynamic get oledCustomColors => oled.OledCustomColors();
  static dynamic get valentineCustomColors => valentine.ValentineCustomColors();
  static dynamic get draculaCustomColors => dracula.DraculaCustomColors();
  static dynamic get nordCustomColors => nord.NordCustomColors();
  static dynamic get coffeeCustomColors => coffee.CoffeeCustomColors();
  static dynamic get tokyoNightCustomColors =>
      tokyo_night.TokyoNightCustomColors();
  static dynamic get solarizedLightCustomColors =>
      solarized_light.SolarizedLightCustomColors();
  static dynamic get oneLightCustomColors => one_light.OneLightCustomColors();
  static dynamic get cyberpunkCustomColors =>
      cyberpunk.CyberpunkCustomColors();
  static dynamic get solarizedDarkCustomColors =>
      solarized_dark.SolarizedDarkCustomColors();
  static dynamic get palenightCustomColors => palenight.PalenightCustomColors();
  static dynamic get horizonCustomColors => horizon.HorizonCustomColors();

  /// Retrieves header colors based on the current context's theme.
  static dynamic getCustomColors(BuildContext context) {
    // Prefer detection by palette name if a PaletteProvider is available (more reliable).
    try {
      final paletteProvider = Provider.of<PaletteProvider>(
        context,
        listen: false,
      );
      final paletteName = paletteProvider.currentPaletteName;
      String resolvedThemeName = paletteName;

      if (paletteName == 'system') {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        resolvedThemeName = brightness == Brightness.dark
            ? 'nsdark'
            : 'nslight';
      }

      switch (resolvedThemeName) {
        case 'nslight':
          return nslight.NSlightCustomColors();
        case 'oled':
          return oled.OledCustomColors();
        case 'valentine':
          return valentine.ValentineCustomColors();
        case 'dracula':
          return dracula.DraculaCustomColors();
        case 'nord':
          return nord.NordCustomColors();
        case 'coffee':
          return coffee.CoffeeCustomColors();
        case 'tokyo_night':
          return tokyo_night.TokyoNightCustomColors();
        case 'solarized_light':
          return solarized_light.SolarizedLightCustomColors();
        case 'one_light':
          return one_light.OneLightCustomColors();
        case 'cyberpunk':
          return cyberpunk.CyberpunkCustomColors();
        case 'solarized_dark':
          return solarized_dark.SolarizedDarkCustomColors();
        case 'palenight':
          return palenight.PalenightCustomColors();
        case 'horizon':
          return horizon.HorizonCustomColors();
        default:
          return nsdark.NSdarkCustomColors();
      }
    } catch (_) {
      // Fallback to color comparison if provider is not available.
    }

    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;
    final secondary = scheme.secondary;

    // Compare with surface or secondary colors of each theme.
    if (surface == nslightPalette.colorScheme.surface ||
        secondary == nslightPalette.colorScheme.secondary) {
      return nslight.NSlightCustomColors();
    } else if (surface == oledPalette.colorScheme.surface ||
        secondary == oledPalette.colorScheme.secondary) {
      return oled.OledCustomColors();
    } else if (surface == valentinePalette.colorScheme.surface ||
        secondary == valentinePalette.colorScheme.secondary) {
      return valentine.ValentineCustomColors();
    } else if (surface == draculaPalette.colorScheme.surface ||
        secondary == draculaPalette.colorScheme.secondary) {
      return dracula.DraculaCustomColors();
    } else if (surface == nordPalette.colorScheme.surface ||
        secondary == nordPalette.colorScheme.secondary) {
      return nord.NordCustomColors();
    } else if (surface == coffeePalette.colorScheme.surface ||
        secondary == coffeePalette.colorScheme.secondary) {
      return coffee.CoffeeCustomColors();
    } else if (surface == tokyoNightPalette.colorScheme.surface ||
        secondary == tokyoNightPalette.colorScheme.secondary) {
      return tokyo_night.TokyoNightCustomColors();
    } else if (surface == solarizedLightPalette.colorScheme.surface ||
        secondary == solarizedLightPalette.colorScheme.secondary) {
      return solarized_light.SolarizedLightCustomColors();
    } else if (surface == oneLightPalette.colorScheme.surface ||
        secondary == oneLightPalette.colorScheme.secondary) {
      return one_light.OneLightCustomColors();
    } else if (surface == cyberpunkPalette.colorScheme.surface ||
        secondary == cyberpunkPalette.colorScheme.secondary) {
      return cyberpunk.CyberpunkCustomColors();
    } else if (surface == solarizedDarkPalette.colorScheme.surface ||
        secondary == solarizedDarkPalette.colorScheme.secondary) {
      return solarized_dark.SolarizedDarkCustomColors();
    } else if (surface == palenightPalette.colorScheme.surface ||
        secondary == palenightPalette.colorScheme.secondary) {
      return palenight.PalenightCustomColors();
    } else if (surface == horizonPalette.colorScheme.surface ||
        secondary == horizonPalette.colorScheme.secondary) {
      return horizon.HorizonCustomColors();
    } else {
      return nsdark.NSdarkCustomColors();
    }
  }

  static ThemeData getPaletteDataByName(String paletteName) {
    switch (paletteName) {
      case 'nsdark':
        return nsdarkPalette;
      case 'nslight':
        return nslightPalette;
      case 'oled':
        return oledPalette;
      case 'valentine':
        return valentinePalette;
      case 'dracula':
        return draculaPalette;
      case 'nord':
        return nordPalette;
      case 'coffee':
        return coffeePalette;
      case 'tokyo_night':
        return tokyoNightPalette;
      case 'solarized_light':
        return solarizedLightPalette;
      case 'one_light':
        return oneLightPalette;
      case 'cyberpunk':
        return cyberpunkPalette;
      case 'solarized_dark':
        return solarizedDarkPalette;
      case 'palenight':
        return palenightPalette;
      case 'horizon':
        return horizonPalette;
      default:
        return nsdarkPalette;
    }
  }
}
