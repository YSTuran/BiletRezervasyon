import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/auth_repository.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  bool _hidePassword = true;

  bool get hidePassword => _hidePassword;

  void togglePasswordVisibility() {
    _hidePassword = !_hidePassword;
    notifyListeners();
  }

  Future<NavigationInstruction?> login({
    required String email,
    required String password,
  }) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      return await _authRepository.login(email: email, password: password);
    } finally {
      setBusy(false);
    }
  }
}
