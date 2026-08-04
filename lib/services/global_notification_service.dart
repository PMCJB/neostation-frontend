import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Notification types supported by the global overlay.
enum GlobalNotificationType { info, success, error }

/// Immutable data holder for a global notification.
class GlobalNotificationData {
  final String id;
  final String message;
  final String? title;
  final Uint8List? imageBytes;
  final IconData? icon;
  final GlobalNotificationType type;
  final double? progress;

  /// When false, the notification stays visible until explicitly dismissed or
  /// updated to auto-dismiss. Use this for long-running operations.
  final bool autoDismiss;

  /// How long the notification remains on screen before auto-dismissing.
  final Duration duration;

  const GlobalNotificationData({
    required this.id,
    required this.message,
    this.title,
    this.imageBytes,
    this.icon,
    required this.type,
    this.progress,
    this.autoDismiss = true,
    this.duration = const Duration(seconds: 4),
  });
}

/// Application-wide notification service that is completely independent of any
/// widget's [BuildContext] or the navigator's overlay.
///
/// A single [GlobalNotificationOverlay] is mounted at the root of [MainScreen]
/// so notifications survive tab and menu changes. This avoids the stuck overlay
/// entries that can happen when [AppNotification]'s overlay is tied to a
/// transient context.
///
/// The service keeps an ordered list of active notifications. The overlay shows
/// the most recent one, while a notification bell dropdown can display the full
/// list with progress.
class GlobalNotificationService {
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  final ValueNotifier<List<GlobalNotificationData>> notifier = ValueNotifier([]);

  /// Displays a global notification. If a notification with the same [id] is
  /// already active, it is updated in place and moved to the end (most recent).
  void show({
    required String id,
    required String message,
    String? title,
    Uint8List? imageBytes,
    IconData? icon,
    GlobalNotificationType type = GlobalNotificationType.info,
    double? progress,
    bool autoDismiss = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    final current = notifier.value;
    final existingIndex = current.indexWhere((n) => n.id == id);
    final updated = GlobalNotificationData(
      id: id,
      message: message,
      title: title,
      imageBytes: imageBytes,
      icon: icon,
      type: type,
      progress: progress,
      autoDismiss: autoDismiss,
      duration: duration,
    );

    if (existingIndex == -1) {
      notifier.value = [...current, updated];
    } else {
      final copy = List<GlobalNotificationData>.from(current);
      copy.removeAt(existingIndex);
      copy.add(updated);
      notifier.value = copy;
    }
  }

  /// Updates an active notification only if its [id] exists.
  void update({
    required String id,
    required String message,
    String? title,
    Uint8List? imageBytes,
    IconData? icon,
    GlobalNotificationType? type,
    double? progress,
    bool? autoDismiss,
    Duration? duration,
  }) {
    final current = notifier.value;
    final index = current.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final existing = current[index];
    notifier.value = [
      ...current.sublist(0, index),
      GlobalNotificationData(
        id: id,
        message: message,
        title: title ?? existing.title,
        imageBytes: imageBytes ?? existing.imageBytes,
        icon: icon ?? existing.icon,
        type: type ?? existing.type,
        progress: progress ?? existing.progress,
        autoDismiss: autoDismiss ?? existing.autoDismiss,
        duration: duration ?? existing.duration,
      ),
      ...current.sublist(index + 1),
    ];
  }

  /// Removes the notification with the given [id], or clears all notifications
  /// when no [id] is provided.
  void dismiss([String? id]) {
    if (id == null) {
      notifier.value = [];
      return;
    }
    notifier.value = notifier.value.where((n) => n.id != id).toList();
  }
}

/// Widget that hosts the global notification layer above [child].
///
/// Mount this once at the root of the main UI (e.g. in [MainScreen]) so the
/// notification layer is never rebuilt or removed by tab navigation.
class GlobalNotificationOverlay extends StatelessWidget {
  final Widget child;

  const GlobalNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<List<GlobalNotificationData>>(
          valueListenable: GlobalNotificationService().notifier,
          builder: (context, notifications, _) {
            if (notifications.isEmpty) return const SizedBox.shrink();
            final data = notifications.last;
            return _GlobalNotificationWidget(key: ValueKey(data.id), data: data);
          },
        ),
      ],
    );
  }
}

class _GlobalNotificationWidget extends StatefulWidget {
  final GlobalNotificationData data;

  const _GlobalNotificationWidget({super.key, required this.data});

  @override
  State<_GlobalNotificationWidget> createState() =>
      _GlobalNotificationWidgetState();
}

class _GlobalNotificationWidgetState extends State<_GlobalNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    if (widget.data.autoDismiss) {
      _scheduleDismiss();
    }
  }

  @override
  void didUpdateWidget(covariant _GlobalNotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.autoDismiss && !oldWidget.data.autoDismiss) {
      _scheduleDismiss();
    }
  }

  void _scheduleDismiss() {
    Future.delayed(
      widget.data.duration - const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        _animationController.reverse().then((_) {
          GlobalNotificationService().dismiss(widget.data.id);
        });
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final Color backgroundColor;
    final Color textColor;
    final IconData icon;

    switch (data.type) {
      case GlobalNotificationType.success:
        backgroundColor = Colors.green.shade700;
        textColor = Colors.white;
        icon = Symbols.check_circle_rounded;
      case GlobalNotificationType.error:
        backgroundColor = Theme.of(context).colorScheme.error;
        textColor = Theme.of(context).colorScheme.onError;
        icon = Symbols.error_rounded;
      case GlobalNotificationType.info:
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurface;
        icon = Symbols.info_rounded;
    }

    return Positioned(
      top: 16.r,
      right: 16.r,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 360.r,
              minWidth: 120.r,
            ),
            padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 10.r),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5.r,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12.r,
                  spreadRadius: -5.r,
                  offset: Offset(0, 10.r),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.imageBytes != null)
                  Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.r),
                      image: DecorationImage(
                        image: MemoryImage(data.imageBytes!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.icon ?? icon,
                      color: textColor,
                      size: 14.r,
                    ),
                  ),
                SizedBox(width: 8.r),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.title != null)
                        Text(
                          data.title!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.r,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        data.message,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.9),
                          fontSize: 10.r,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: data.title != null ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data.progress != null) ...[
                        SizedBox(height: 6.r),
                        LinearProgressIndicator(
                          value: data.progress,
                          minHeight: 3.r,
                          color: textColor,
                          backgroundColor: textColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
