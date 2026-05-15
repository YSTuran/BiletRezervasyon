import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../trip/presentation/helpers/trip_presentation_helper.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';
import '../view_models/notification_view_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NotificationViewModel(
        repository: context.read<NotificationRepository>(),
      )..load(),
      child: const _NotificationView(),
    );
  }
}

class _NotificationView extends StatelessWidget {
  const _NotificationView();

  IconData _iconFor(AppNotification notification) {
    return switch (notification.category) {
      'reservation_approved' => Icons.check_circle_outline,
      'reservation_rejected' => Icons.cancel_outlined,
      'reservation_expired' => Icons.timer_off_outlined,
      'trip_cancelled' => Icons.event_busy_outlined,
      'refund_requested' => Icons.assignment_return_outlined,
      'refund_approved' => Icons.verified_outlined,
      'refund_rejected' => Icons.block_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationViewModel>();

    Widget body;
    if (viewModel.isBusy && viewModel.notifications.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.errorMessage != null &&
        viewModel.notifications.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: viewModel.load,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    } else if (viewModel.notifications.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Henüz bildiriminiz bulunmuyor.'),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: viewModel.notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = viewModel.notifications[index];
            final isUnread = notification.isUnread;
            return Card(
              color: isUnread
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: Icon(_iconFor(notification)),
                title: Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.body),
                      const SizedBox(height: 6),
                      Text(
                        TripPresentationHelper.formatDateTime(
                          notification.createdAt,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                trailing: isUnread
                    ? IconButton(
                        tooltip: 'Okundu İşaretle',
                        onPressed: () {
                          viewModel.markRead(notification.id);
                        },
                        icon: const Icon(Icons.done_all_outlined),
                      )
                    : null,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (viewModel.unreadCount > 0)
            IconButton(
              tooltip: 'Tümünü okundu işaretle',
              onPressed: viewModel.isBusy ? null : viewModel.markAllRead,
              icon: const Icon(Icons.done_all_outlined),
            ),
        ],
      ),
      body: body,
    );
  }
}
