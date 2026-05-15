import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationListResult>(
      future: context.read<NotificationRepository>().fetchNotifications(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.unreadCount ?? 0;

        return IconButton(
          tooltip: unreadCount > 0
              ? '$unreadCount okunmamış bildirim'
              : 'Bildirimler',
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.notifications);
          },
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
