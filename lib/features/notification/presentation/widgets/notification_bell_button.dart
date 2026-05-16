import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  Future<NotificationListResult>? _notificationsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationsFuture ??= context
        .read<NotificationRepository>()
        .fetchNotifications();
  }

  Future<void> _openNotifications() async {
    final navigator = Navigator.of(context);

    await navigator.pushNamed(AppRoutes.notifications);
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsFuture = context
          .read<NotificationRepository>()
          .fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationListResult>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.unreadCount ?? 0;

        return IconButton(
          tooltip: unreadCount > 0
              ? '$unreadCount okunmamış bildirim'
              : 'Bildirimler',
          onPressed: _openNotifications,
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
