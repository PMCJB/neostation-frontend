import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/services/global_notification_service.dart';

/// Notification bell icon that opens a dropdown with all active global
/// notifications, including their progress.
///
/// Designed to live in the top header next to the clock.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<GlobalNotificationData>>(
      valueListenable: GlobalNotificationService().notifier,
      builder: (context, notifications, _) {
        final hasNotifications = notifications.isNotEmpty;
        return GestureDetector(
          onTap: () => _openDropdown(context),
          child: Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: hasNotifications
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  hasNotifications
                      ? Symbols.notifications_active_rounded
                      : Symbols.notifications_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 18.r,
                ),
                if (hasNotifications)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8.r,
                      height: 8.r,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.r,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDropdown(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4.r,
        offset.dx + size.width,
        offset.dy + size.height + 4.r,
      ),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      items: [
        _NotificationsDropdownMenu(),
      ],
    );
  }
}

class _NotificationsDropdownMenu extends PopupMenuEntry<void> {
  const _NotificationsDropdownMenu();

  @override
  State<StatefulWidget> createState() => _NotificationsDropdownMenuState();

  @override
  double get height => 0;

  @override
  bool represents(void value) => false;
}

class _NotificationsDropdownMenuState extends State<_NotificationsDropdownMenu> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<GlobalNotificationData>>(
      valueListenable: GlobalNotificationService().notifier,
      builder: (context, notifications, _) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 300.r,
            minWidth: 200.r,
            maxHeight: 360.r,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocale.notifications.getString(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12.r,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (notifications.isNotEmpty)
                      GestureDetector(
                        onTap: () => GlobalNotificationService().dismiss(),
                        child: Text(
                          AppLocale.clearAll.getString(context),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10.r,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Center(
                    child: Text(
                      AppLocale.noActiveNotifications.getString(context),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 11.r,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1.r,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      return _NotificationDropdownItem(
                        data: notifications[index],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationDropdownItem extends StatelessWidget {
  final GlobalNotificationData data;

  const _NotificationDropdownItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData icon;

    switch (data.type) {
      case GlobalNotificationType.success:
        iconColor = Colors.green.shade400;
        icon = Symbols.check_circle_rounded;
      case GlobalNotificationType.error:
        iconColor = Theme.of(context).colorScheme.error;
        icon = Symbols.error_rounded;
      case GlobalNotificationType.info:
        iconColor = Theme.of(context).colorScheme.primary;
        icon = Symbols.info_rounded;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16.r),
          SizedBox(width: 8.r),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.title != null)
                  Text(
                    data.title!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 11.r,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  data.message,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                    fontSize: 10.r,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (data.progress != null) ...[
                  SizedBox(height: 6.r),
                  LinearProgressIndicator(
                    value: data.progress,
                    minHeight: 3.r,
                    color: iconColor,
                    backgroundColor: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.r),
          GestureDetector(
            onTap: () => GlobalNotificationService().dismiss(data.id),
            child: Icon(
              Symbols.close_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.5,
              ),
              size: 14.r,
            ),
          ),
        ],
      ),
    );
  }
}
