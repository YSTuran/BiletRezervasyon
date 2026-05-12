import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/presentation/view_models/base_view_model.dart';
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

  String get email => _authRepository.resolveEmail(preferredEmail: userEmail);
  String get fullName => _authRepository.resolveFullName();

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
      throw UserMessageException('Cikis yapilamadi: ${error.code}');
    } catch (_) {
      throw const UserMessageException('Cikis yapilamadi.');
    } finally {
      setBusy(false);
    }
  }
}
