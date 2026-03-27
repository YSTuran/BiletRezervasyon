import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterViewModel extends BaseViewModel {
  RegisterViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  UserRole _selectedRole = UserRole.normalUser;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  UserRole get selectedRole => _selectedRole;
  bool get hidePassword => _hidePassword;
  bool get hideConfirmPassword => _hideConfirmPassword;

  void updateSelectedRole(UserRole role) {
    if (_selectedRole == role) {
      return;
    }
    _selectedRole = role;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _hidePassword = !_hidePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _hideConfirmPassword = !_hideConfirmPassword;
    notifyListeners();
  }

  Future<NavigationInstruction?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      return await _authRepository.register(
        fullName: fullName,
        email: email,
        password: password,
        preferredRole: _selectedRole,
      );
    } finally {
      setBusy(false);
    }
  }
}
