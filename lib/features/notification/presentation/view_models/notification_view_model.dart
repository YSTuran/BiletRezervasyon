import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';

class NotificationViewModel extends BaseViewModel {
  NotificationViewModel({required NotificationRepository repository})
    : _repository = repository;

  final NotificationRepository _repository;

  List<AppNotification> _notifications = const [];
  int _unreadCount = 0;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      final result = await _repository.fetchNotifications();
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
      _errorMessage = null;
      notifyListeners();
    } on NotificationActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      final updatedNotification = await _repository.markRead(notificationId);
      if (updatedNotification == null) {
        return;
      }
      _replaceNotification(updatedNotification);
      _unreadCount = _notifications.where((item) => item.isUnread).length;
      notifyListeners();
    } on NotificationActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      final result = await _repository.markAllRead();
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
      _errorMessage = null;
      notifyListeners();
    } on NotificationActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  void _replaceNotification(AppNotification updatedNotification) {
    final index = _notifications.indexWhere(
      (notification) => notification.id == updatedNotification.id,
    );
    if (index == -1) {
      _notifications = [updatedNotification, ..._notifications];
      return;
    }

    final nextNotifications = [..._notifications];
    nextNotifications[index] = updatedNotification;
    _notifications = nextNotifications;
  }
}
