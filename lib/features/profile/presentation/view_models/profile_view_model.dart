import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';

class ProfileViewModel extends BaseViewModel {
  ProfileViewModel({
    this.userEmail,
    this.onLogout,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? AuthRepository();

  final String? userEmail;
  final Future<void> Function()? onLogout;
  final AuthRepository _authRepository;
  UserRole? _role;

  String get email => _authRepository.resolveEmail(preferredEmail: userEmail);
  String get fullName => _authRepository.resolveFullName();
  bool get canDeleteAccount => _role != null && _role != UserRole.admin;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _role = await _authRepository.resolveCurrentUserRole();
    } catch (_) {
      _role = null;
    } finally {
      setBusy(false);
    }
  }

  Future<void> updateFullName(String fullName) async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      await _authRepository.updateFullName(fullName);
    } finally {
      setBusy(false);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      setBusy(false);
    }
  }

  Future<String?> deleteAccount({required String currentPassword}) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      await _authRepository.deleteAccount(currentPassword: currentPassword);
      return AppRoutes.login;
    } finally {
      setBusy(false);
    }
  }

  Future<String?> logout() async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      if (onLogout != null) {
        await onLogout!.call();
        return null;
      }

      await _authRepository.signOut();
      return AppRoutes.login;
    } on FirebaseAuthException catch (error) {
      throw UserMessageException('Çıkış yapılamadı: ${error.code}');
    } catch (_) {
      throw const UserMessageException('Çıkış yapılamadı.');
    } finally {
      setBusy(false);
    }
  }
}
