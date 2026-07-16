import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:marquee/marquee.dart';
import 'package:outlined_text/outlined_text.dart';

class MarqueeText extends StatelessWidget {
  final String text;
  final bool isActive;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double? height;
  final List<OutlinedTextStroke>? strokes;

  const MarqueeText({
    super.key,
    required this.text,
    required this.isActive,
    this.style,
    this.textAlign,
    this.height,
    this.strokes,
  });

  Widget _buildOutlinedText(TextStyle style, {TextOverflow? overflow}) {
    final textWidget = Text(
      text,
      style: style,
      maxLines: 1,
      overflow: overflow,
      textAlign: textAlign,
    );

    if (strokes == null || strokes!.isEmpty) {
      return textWidget;
    }

    return OutlinedText(
      text: textWidget,
      strokes: strokes!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use TextPainter to measure if the text overflows the available width
        // and to get the exact height of the text
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        final bool overflows = textPainter.size.width > constraints.maxWidth;
        final double textHeight = textPainter.size.height;
        final double contentHeight = height ?? textHeight;

        // When an outline is requested and the text overflows, use a custom
        // outlined marquee because the base Marquee widget does not expose a
        // way to wrap its internal Text with OutlinedText.
        final bool useOutlinedMarquee =
            overflows && isActive && strokes != null && strokes!.isNotEmpty;

        return SizedBox(
          width: double.infinity,
          height: contentHeight,
          child: useOutlinedMarquee
              ? _OutlinedMarquee(
                  text: text,
                  style: effectiveStyle,
                  strokes: strokes!,
                  textPainter: textPainter,
                )
              : (overflows && isActive)
                  ? Marquee(
                      text: text,
                      style: effectiveStyle,
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      blankSpace:
                          24.r, // Space between the end and the start of the text
                      velocity: 50.0, // Smooth scrolling speed
                      pauseAfterRound: const Duration(
                        seconds: 3,
                      ), // Pause at the end of each round
                      accelerationDuration: const Duration(seconds: 1),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 500),
                      decelerationCurve: Curves.easeOut,
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _buildOutlinedText(
                        effectiveStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
        );
      },
    );
  }
}

/// A simple horizontal marquee that uses [OutlinedText] so the scrolling text
/// keeps its stroke. It duplicates the text with a blank gap and translates the
/// whole row from right to left, then loops.
class _OutlinedMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<OutlinedTextStroke> strokes;
  final TextPainter textPainter;

  const _OutlinedMarquee({
    required this.text,
    required this.style,
    required this.strokes,
    required this.textPainter,
  });

  @override
  State<_OutlinedMarquee> createState() => _OutlinedMarqueeState();
}

class _OutlinedMarqueeState extends State<_OutlinedMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _blankSpace = 24.0;
  static const double _velocity = 50.0; // logical pixels per second

  @override
  void initState() {
    super.initState();

    final textWidth = widget.textPainter.size.width;
    final loopDistance = textWidth + _blankSpace;
    final durationSeconds = loopDistance / _velocity;

    _controller = AnimationController(
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
      vsync: this,
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidth = widget.textPainter.size.width;
    final loopDistance = textWidth + _blankSpace;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = -_controller.value * loopDistance;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OutlinedText(
                  text: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                  ),
                  strokes: widget.strokes,
                ),
                SizedBox(width: _blankSpace.r),
                OutlinedText(
                  text: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                  ),
                  strokes: widget.strokes,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
