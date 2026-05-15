import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../domain/models/app_notification.dart';

class NotificationRepository {
  Future<NotificationListResult> fetchNotifications() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'listNotifications',
      );
      return NotificationListResult(
        notifications: _parseNotifications(response['notifications']),
        unreadCount: response['unreadCount'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (error) {
      throw NotificationActionException(
        _mapNotificationError(error.code, error.message),
      );
    }
  }

  Future<AppNotification?> markRead(String notificationId) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'markNotificationRead',
        data: {'notificationId': notificationId},
      );
      return _parseNotification(response['notification']);
    } on FirebaseFunctionsException catch (error) {
      throw NotificationActionException(
        _mapNotificationError(error.code, error.message),
      );
    }
  }

  Future<NotificationListResult> markAllRead() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'markAllNotificationsRead',
      );
      return NotificationListResult(
        notifications: _parseNotifications(response['notifications']),
        unreadCount: response['unreadCount'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (error) {
      throw NotificationActionException(
        _mapNotificationError(error.code, error.message),
      );
    }
  }

  AppNotification? _parseNotification(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return AppNotification.fromJson(_toMap(value));
  }

  List<AppNotification> _parseNotifications(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((notification) => AppNotification.fromJson(_toMap(notification)))
        .toList();
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) => MapEntry('$key', data));
  }

  String _mapNotificationError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Bildirim bulunamadı.';
      case 'permission-denied':
        return 'Bu işlem için yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Bildirim işlemi tamamlanamadı.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Bildirim işlemi tamamlanamadı.';
    }
  }
}

class NotificationListResult {
  const NotificationListResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}

class NotificationActionException implements Exception {
  const NotificationActionException(this.message);

  final String message;
}
