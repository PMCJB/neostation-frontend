import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Notification types supported by the global notification center.
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

  /// How long the notification remains listed before auto-dismissing.
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

/// Application-wide notification center.
///
/// Notifications are kept in an ordered list exposed through [notifier]. The
/// header notification bell renders the list in a dropdown, including progress
/// bars. There is no floating overlay; every notification lives in the dropdown.
///
/// Auto-dismiss is handled here so notifications still time out even when the
/// dropdown is closed.
class GlobalNotificationService {
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  final ValueNotifier<List<GlobalNotificationData>> notifier = ValueNotifier([]);
  final Map<String, Timer> _dismissTimers = {};

  /// Displays a notification. If a notification with the same [id] is already
  /// active, it is updated in place and moved to the end (most recent).
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

    if (autoDismiss) {
      _scheduleDismiss(id, duration);
    } else {
      _cancelDismiss(id);
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
    final newAutoDismiss = autoDismiss ?? existing.autoDismiss;
    final newDuration = duration ?? existing.duration;

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
        autoDismiss: newAutoDismiss,
        duration: newDuration,
      ),
      ...current.sublist(index + 1),
    ];

    if (newAutoDismiss) {
      _scheduleDismiss(id, newDuration);
    } else {
      _cancelDismiss(id);
    }
  }

  /// Removes the notification with the given [id], or clears all notifications
  /// when no [id] is provided.
  void dismiss([String? id]) {
    if (id == null) {
      for (final timer in _dismissTimers.values) {
        timer.cancel();
      }
      _dismissTimers.clear();
      notifier.value = [];
      return;
    }

    _cancelDismiss(id);
    notifier.value = notifier.value.where((n) => n.id != id).toList();
  }

  void _scheduleDismiss(String id, Duration duration) {
    _dismissTimers[id]?.cancel();
    _dismissTimers[id] = Timer(duration, () => dismiss(id));
  }

  void _cancelDismiss(String id) {
    _dismissTimers[id]?.cancel();
    _dismissTimers.remove(id);
  }
}
