import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Shared liquid-glass lens look for NeoStation's floating chrome.
///
/// Every control rendered over the selected game's fanart — the list sidebar,
/// the action rail, the details tab pill, the footer pills, the header tab
/// strip and the system grid cards — uses the same recipe so the whole chrome
/// reads as one material. Tuning the look is a matter of editing this single
/// file.
///
/// On Impeller the lens refracts the live backdrop; on Skia/Web it degrades
/// to a frosted (blur + tint + border) look, which is cheaper than full
/// capture and reads the same at a glance.
abstract final class LiquidChrome {
  /// Glass tint: derived from the theme's scaffold background color, so the
  /// chrome always reads as a pane of the app's own surface rather than a
  /// fixed tint.
  static Color tint(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.75);

  /// A visible frosted-glass panel WITHOUT a live blur: a translucent gradient
  /// of the scaffold color with a soft top sheen and a hairline border.
  ///
  /// Use this for chrome that is always on screen (the header pills): real
  /// backdrop blur re-samples every frame the content behind changes, which is
  /// what made the header feel heavy. This reads as glass at zero per-frame
  /// cost.
  static BoxDecoration panel(BuildContext context, {double cornerRadius = 14}) {
    final theme = Theme.of(context);
    final base = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
          base.withValues(alpha: isDark ? 0.45 : 0.55),
          base.withValues(alpha: isDark ? 0.60 : 0.70),
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
      borderRadius: BorderRadius.circular(cornerRadius),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.16 : 0.10,
        ),
        width: 1,
      ),
    );
  }

  /// Base glass look for the chrome floating over fanart.
  static LiquidGlassStyle style(
    BuildContext context, {
    double cornerRadius = 14,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: 1,
        lightIntensity: 0.6,
      ),
      appearance: LiquidGlassAppearance(
        color: tint(context),
        blur: const LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
        saturation: 1.5,
      ),
      refraction: LiquidGlassRefraction(
        distortion: 0.75,
        distortionWidth: 20,
        magnification: 1.0,
      ),
    );
  }
}
