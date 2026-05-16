import 'package:flutter/foundation.dart';

abstract class BaseViewModel extends ChangeNotifier {
  bool _isBusy = false;
  bool _isDisposed = false;

  bool get isBusy => _isBusy;

  @protected
  void setBusy(bool value) {
    if (_isDisposed) {
      return;
    }
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
