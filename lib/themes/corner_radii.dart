import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Corner radius tokens for NeoStation themes.
///
/// The raw radius values are stored as private doubles and converted to
/// [BorderRadius] through public getters using `flutter_screenutil`, so they
/// are only resolved when the widget tree is built (after ScreenUtil has been
/// initialized).
///
/// - [boxesExternal]: outer corners for cards, dialogs, alerts, etc.
/// - [boxesInternal]: inner corners for cards, dialogs, alerts, etc.
/// - [fieldsExternal]: outer corners for buttons, inputs, selects, tabs, etc.
/// - [fieldsInternal]: inner corners for buttons, inputs, selects, tabs, etc.
@immutable
class CornerRadii extends ThemeExtension<CornerRadii> {
  final double _boxesExternal;
  final double _boxesInternal;
  final double _fieldsExternal;
  final double _fieldsInternal;

  const CornerRadii({
    required double boxesExternal,
    required double boxesInternal,
    required double fieldsExternal,
    required double fieldsInternal,
  })  : _boxesExternal = boxesExternal,
        _boxesInternal = boxesInternal,
        _fieldsExternal = fieldsExternal,
        _fieldsInternal = fieldsInternal;

  /// Default radii used by every theme for now. Override per theme later.
  factory CornerRadii.standard() {
    return const CornerRadii(
      boxesExternal: 14,
      boxesInternal: 12,
      fieldsExternal: 14,
      fieldsInternal: 12,
    );
  }

  /// Sharp corners (no radius). Useful for themes like Cyberpunk.
  factory CornerRadii.zero() {
    return const CornerRadii(
      boxesExternal: 0,
      boxesInternal: 0,
      fieldsExternal: 0,
      fieldsInternal: 0,
    );
  }

  /// Scaled [BorderRadius] tokens (uses flutter_screenutil).
  BorderRadius get boxesExternal => BorderRadius.circular(_boxesExternal.r);
  BorderRadius get boxesInternal => BorderRadius.circular(_boxesInternal.r);
  BorderRadius get fieldsExternal => BorderRadius.circular(_fieldsExternal.r);
  BorderRadius get fieldsInternal => BorderRadius.circular(_fieldsInternal.r);

  /// Raw design-time radius values (before flutter_screenutil scaling).
  double get boxesExternalRaw => _boxesExternal;
  double get boxesInternalRaw => _boxesInternal;
  double get fieldsExternalRaw => _fieldsExternal;
  double get fieldsInternalRaw => _fieldsInternal;

  /// Scaled raw radius values, for widgets that expect a `double` radius.
  double get boxesExternalRadius => _boxesExternal.r;
  double get boxesInternalRadius => _boxesInternal.r;
  double get fieldsExternalRadius => _fieldsExternal.r;
  double get fieldsInternalRadius => _fieldsInternal.r;

  static CornerRadii of(BuildContext context) {
    final radii = Theme.of(context).extension<CornerRadii>();
    assert(radii != null, 'CornerRadii extension is missing from the theme');
    return radii ?? CornerRadii.standard();
  }

  @override
  CornerRadii copyWith({
    double? boxesExternal,
    double? boxesInternal,
    double? fieldsExternal,
    double? fieldsInternal,
  }) {
    return CornerRadii(
      boxesExternal: boxesExternal ?? _boxesExternal,
      boxesInternal: boxesInternal ?? _boxesInternal,
      fieldsExternal: fieldsExternal ?? _fieldsExternal,
      fieldsInternal: fieldsInternal ?? _fieldsInternal,
    );
  }

  @override
  CornerRadii lerp(CornerRadii? other, double t) {
    if (other == null) return this;
    return CornerRadii(
      boxesExternal: lerpDouble(_boxesExternal, other._boxesExternal, t)!,
      boxesInternal: lerpDouble(_boxesInternal, other._boxesInternal, t)!,
      fieldsExternal: lerpDouble(_fieldsExternal, other._fieldsExternal, t)!,
      fieldsInternal: lerpDouble(_fieldsInternal, other._fieldsInternal, t)!,
    );
  }
}
