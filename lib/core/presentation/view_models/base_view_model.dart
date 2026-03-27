import 'package:flutter/foundation.dart';

abstract class BaseViewModel extends ChangeNotifier {
  bool _isBusy = false;

  bool get isBusy => _isBusy;

  @protected
  void setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }
}
