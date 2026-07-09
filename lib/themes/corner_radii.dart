import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Corner radius tokens for NeoStation themes.
///
/// - [boxesExternal]: outer corners for cards, dialogs, alerts, etc.
/// - [boxesInternal]: inner corners for cards, dialogs, alerts, etc.
/// - [fieldsExternal]: outer corners for buttons, inputs, selects, tabs, etc.
/// - [fieldsInternal]: inner corners for buttons, inputs, selects, tabs, etc.
@immutable
class CornerRadii extends ThemeExtension<CornerRadii> {
  final BorderRadius boxesExternal;
  final BorderRadius boxesInternal;
  final BorderRadius fieldsExternal;
  final BorderRadius fieldsInternal;

  const CornerRadii({
    required this.boxesExternal,
    required this.boxesInternal,
    required this.fieldsExternal,
    required this.fieldsInternal,
  });

  /// Default radii used by every theme for now. Override per theme later.
  factory CornerRadii.standard() {
    return CornerRadii(
      boxesExternal: BorderRadius.circular(14.r),
      boxesInternal: BorderRadius.circular(12.r),
      fieldsExternal: BorderRadius.circular(14.r),
      fieldsInternal: BorderRadius.circular(12.r),
    );
  }

  static CornerRadii of(BuildContext context) {
    final radii = Theme.of(context).extension<CornerRadii>();
    assert(radii != null, 'CornerRadii extension is missing from the theme');
    return radii ?? CornerRadii.standard();
  }

  @override
  CornerRadii copyWith({
    BorderRadius? boxesExternal,
    BorderRadius? boxesInternal,
    BorderRadius? fieldsExternal,
    BorderRadius? fieldsInternal,
  }) {
    return CornerRadii(
      boxesExternal: boxesExternal ?? this.boxesExternal,
      boxesInternal: boxesInternal ?? this.boxesInternal,
      fieldsExternal: fieldsExternal ?? this.fieldsExternal,
      fieldsInternal: fieldsInternal ?? this.fieldsInternal,
    );
  }

  @override
  CornerRadii lerp(CornerRadii? other, double t) {
    if (other == null) return this;
    return CornerRadii(
      boxesExternal: BorderRadius.lerp(boxesExternal, other.boxesExternal, t)!,
      boxesInternal: BorderRadius.lerp(boxesInternal, other.boxesInternal, t)!,
      fieldsExternal: BorderRadius.lerp(fieldsExternal, other.fieldsExternal, t)!,
      fieldsInternal: BorderRadius.lerp(fieldsInternal, other.fieldsInternal, t)!,
    );
  }
}
