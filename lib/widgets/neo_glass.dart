import 'dart:ui' as ui;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';

/// A performant, dependency-free frosted-glass surface.
///
/// It replicates the cheap "frosted" path of the liquid-glass packages we
/// evaluated: a single engine [BackdropFilter] blur pass over a translucent
/// tint, clipped to the panel's own shape, with a hairline border and a
/// canvas-drawn specular rim.
///
/// Deliberately does NOT do the expensive parts of a full liquid-glass
/// package — refraction, distortion, chromatic aberration and the shader that
/// re-samples the live backdrop every frame. Those shader passes are what made
/// the previous dependency heavy on low-end GPUs (Android TV included). The
/// engine blur is optimized and clipped to the small panel area, so this stays
/// cheap even when the content behind the glass changes every frame.
class NeoGlass extends StatelessWidget {
  const NeoGlass({
    super.key,
    required this.child,
    this.cornerRadius = 14,
    this.blur = 3,
    this.tint,
    this.borderColor,
    this.padding,
    this.rimIntensity = 0.45,
  });

  final Widget child;

  /// Corner radius of the glass panel.
  final double cornerRadius;

  /// Gaussian blur sigma applied to the backdrop.
  ///
  /// `0` disables the blur entirely — the surface becomes a flat translucent
  /// panel (the cheapest mode, zero backdrop cost). Keep it modest on low-end
  /// GPUs; the cost scales with the blurred area.
  final double blur;

  /// Translucent fill tinted over the blurred backdrop. Defaults to a
  /// scaffold-background tint.
  final Color? tint;

  /// Hairline border color. Defaults to a subtle outline.
  final Color? borderColor;

  /// Inset applied inside the glass around [child].
  final EdgeInsetsGeometry? padding;

  /// Strength of the specular rim highlight (0.0–1.0).
  final double rimIntensity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassTint =
        tint ?? theme.scaffoldBackgroundColor.withValues(alpha: 0.60);
    final border =
        borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.30);
    final borderRadius = BorderRadius.circular(cornerRadius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: glassTint,
        border: Border.all(color: border, width: 1.h),
        borderRadius: borderRadius,
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    // One engine blur pass over the backdrop, clipped to the panel shape.
    // This is the whole "frost" — no refraction shader, no per-frame capture.
    if (blur > 0) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          surface,
          // Specular rim: a light-gradient stroke around the glass edge, drawn
          // in pure Canvas (cheap, no shader). Mirrors the "optical border"
          // look of the liquid-glass packages without the GPU cost.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassRimPainter(
                  cornerRadius: cornerRadius,
                  intensity: rimIntensity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the glass rim: a soft specular highlight sweeping with the light
/// direction plus a sharp inner edge, matching how the liquid-glass packages
/// shade their borders — but in plain Canvas.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.cornerRadius, required this.intensity});

  final double cornerRadius;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final bounds = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(cornerRadius)),
      );

    // Light from the top-left. The rim stays light all around — it only fades
    // in strength towards the far edge, it never turns dark.
    final light = Alignment.topLeft;
    final sweep = LinearGradient(
      begin: light,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.48 * intensity),
        Colors.white.withValues(alpha: 0.32 * intensity),
        Colors.white.withValues(alpha: 0.16 * intensity),
        Colors.white.withValues(alpha: 0.24 * intensity),
      ],
      stops: const [0.0, 0.3, 0.6, 0.9],
    ).createShader(bounds);

    // Pass 1: soft outer glow — a uniform light sweep around the edge.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.h
        ..shader = sweep,
    );

    // Pass 2: sharper inner rim, brightest near the light and fading to a
    // faint highlight on the far side — never dark.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7.h
        ..shader = LinearGradient(
          begin: light,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.32 * intensity),
            Colors.white.withValues(alpha: 0.16 * intensity),
            Colors.white.withValues(alpha: 0.08 * intensity),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.intensity != intensity;
}
