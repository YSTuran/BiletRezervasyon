import 'package:firebase_auth/firebase_auth.dart';

import '../app_routes.dart';
import '../repositories/auth_repository.dart';
import 'base_view_model.dart';

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
