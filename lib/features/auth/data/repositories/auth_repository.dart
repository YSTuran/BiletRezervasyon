import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../services/user_sync_service.dart';

class UserMessageException implements Exception {
  const UserMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NavigationInstruction {
  const NavigationInstruction({required this.route, this.message});

  final String route;
  final String? message;
}

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Future<NavigationInstruction> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return _syncAfterAuth(
        preferredFullName: credential.user?.displayName,
        deleteCurrentUserOnFailure: false,
      );
    } on FirebaseAuthException catch (error) {
      throw UserMessageException(_mapLoginError(error.code));
    }
  }

  Future<NavigationInstruction> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole preferredRole,
  }) async {
    try {
      final normalizedEmail = email.trim();
      final currentUser = _firebaseAuth.currentUser;
      final currentEmail = currentUser?.email?.toLowerCase();
      var createdNewFirebaseUser = false;

      if (currentUser == null ||
          currentEmail != normalizedEmail.toLowerCase()) {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        createdNewFirebaseUser = true;
        final createdUser = credential.user;
        if (createdUser != null &&
            (createdUser.displayName ?? '').trim() != fullName) {
          await createdUser.updateDisplayName(fullName);
        }
      } else if ((currentUser.displayName ?? '').trim() != fullName) {
        await currentUser.updateDisplayName(fullName);
      }

      return _syncAfterAuth(
        preferredFullName: fullName,
        preferredRole: preferredRole,
        deleteCurrentUserOnFailure: createdNewFirebaseUser,
      );
    } on FirebaseAuthException catch (error) {
      throw UserMessageException(_mapRegisterError(error.code));
    }
  }

  Future<NavigationInstruction> resolveHomeRoute() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const NavigationInstruction(route: AppRoutes.login);
    }

    try {
      final syncedUser = await UserSyncService.syncSignedInUser(
        preferredFullName: user.displayName,
      );
      return NavigationInstruction(
        route: AppRoutes.homeForRole(syncedUser.role),
      );
    } on UserSyncException catch (error) {
      await _signOutSilently();
      return NavigationInstruction(
        route: AppRoutes.login,
        message: _mapHomeResolverSyncFailure(error.code, error.message),
      );
    } catch (_) {
      await _signOutSilently();
      return const NavigationInstruction(
        route: AppRoutes.login,
        message: 'Oturum dogrulanamadi. Lutfen tekrar giris yapin.',
      );
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String? resolveCurrentUserId() => _firebaseAuth.currentUser?.uid;

  String resolveFullName() {
    final displayName = _firebaseAuth.currentUser?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = _firebaseAuth.currentUser?.email?.trim() ?? '';
    if (email.contains('@')) {
      final prefix = email.split('@').first.replaceAll('.', ' ').trim();
      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return 'Yeni Kullanici';
  }

  String resolveEmail({String? preferredEmail}) {
    final passedEmail = preferredEmail?.trim() ?? '';
    if (passedEmail.isNotEmpty) {
      return passedEmail;
    }

    final authEmail = _firebaseAuth.currentUser?.email?.trim() ?? '';
    if (authEmail.isNotEmpty) {
      return authEmail;
    }

    return 'E-posta bilgisi yok';
  }

  Future<void> updateFullName(String fullName) async {
    final trimmedFullName = fullName.trim();
    if (trimmedFullName.isEmpty) {
      throw const UserMessageException('Ad-soyad zorunludur.');
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const UserMessageException('Aktif kullanici bulunamadi.');
    }

    try {
      if ((user.displayName ?? '').trim() != trimmedFullName) {
        await user.updateDisplayName(trimmedFullName);
      }
      await UserSyncService.syncSignedInUser(
        preferredFullName: trimmedFullName,
      );
    } on FirebaseAuthException catch (error) {
      throw UserMessageException(_mapProfileAuthError(error.code));
    } on UserSyncException catch (error) {
      throw UserMessageException(
        _mapAuthSyncFailure(error.code, error.message),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final trimmedCurrentPassword = currentPassword.trim();
    if (trimmedCurrentPassword.isEmpty) {
      throw const UserMessageException('Mevcut sifre zorunludur.');
    }
    if (newPassword.length < 6) {
      throw const UserMessageException(
        'Yeni sifre en az 6 karakter olmalidir.',
      );
    }

    final user = _requirePasswordUser();
    try {
      await _reauthenticate(user: user, password: trimmedCurrentPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw UserMessageException(_mapProfileAuthError(error.code));
    }
  }

  Future<void> deleteAccount({required String currentPassword}) async {
    final trimmedCurrentPassword = currentPassword.trim();
    if (trimmedCurrentPassword.isEmpty) {
      throw const UserMessageException('Hesabi silmek icin sifrenizi girin.');
    }

    final user = _requirePasswordUser();
    try {
      await _reauthenticate(user: user, password: trimmedCurrentPassword);
      await PostgresCallableService.call(functionName: 'deleteMyAccount');
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw UserMessageException(_mapProfileAuthError(error.code));
    } on FirebaseFunctionsException catch (error) {
      throw UserMessageException(
        _mapProfileDeleteError(error.code, error.message),
      );
    }
  }

  Future<NavigationInstruction> _syncAfterAuth({
    String? preferredFullName,
    UserRole? preferredRole,
    required bool deleteCurrentUserOnFailure,
  }) async {
    try {
      final syncedUser = await UserSyncService.syncSignedInUser(
        preferredFullName: preferredFullName,
        preferredRole: preferredRole,
      );
      return NavigationInstruction(
        route: AppRoutes.homeForRole(syncedUser.role),
      );
    } on UserSyncException catch (error) {
      await _rollbackAfterSyncFailure(
        deleteCurrentUser: deleteCurrentUserOnFailure,
      );
      throw UserMessageException(
        _mapAuthSyncFailure(error.code, error.message),
      );
    } catch (_) {
      await _rollbackAfterSyncFailure(
        deleteCurrentUser: deleteCurrentUserOnFailure,
      );
      throw const UserMessageException(
        'Hesap senkronizasyonu tamamlanamadi. Lutfen tekrar deneyin.',
      );
    }
  }

  User _requirePasswordUser() {
    final user = _firebaseAuth.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw const UserMessageException(
        'Aktif e-posta/sifre kullanicisi bulunamadi.',
      );
    }
    return user;
  }

  Future<void> _reauthenticate({
    required User user,
    required String password,
  }) async {
    final email = user.email?.trim() ?? '';
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  String _mapLoginError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-posta formati gecersiz.';
      case 'user-disabled':
        return 'Bu kullanici devre disi birakilmis.';
      case 'user-not-found':
        return 'Bu e-posta icin hesap bulunamadi.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya sifre hatali.';
      case 'too-many-requests':
        return 'Cok fazla deneme yapildi. Lutfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ag baglantisi hatasi. Interneti kontrol edin.';
      default:
        return 'Giris yapilamadi: $code';
    }
  }

  String _mapRegisterError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var.';
      case 'invalid-email':
        return 'E-posta formati gecersiz.';
      case 'weak-password':
        return 'Sifre gucsuz. En az 6 karakter kullanin.';
      case 'operation-not-allowed':
        return 'Email-sifre kaydi su an kapali.';
      case 'network-request-failed':
        return 'Ag baglantisi hatasi. Interneti kontrol edin.';
      default:
        return 'Kayit tamamlanamadi: $code';
    }
  }

  String _mapProfileAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mevcut sifre hatali.';
      case 'weak-password':
        return 'Yeni sifre gucsuz. En az 6 karakter kullanin.';
      case 'requires-recent-login':
        return 'Bu islem icin tekrar giris yapmaniz gerekiyor.';
      case 'too-many-requests':
        return 'Cok fazla deneme yapildi. Lutfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ag baglantisi hatasi. Interneti kontrol edin.';
      default:
        return 'Profil islemi tamamlanamadi: $code';
    }
  }

  String _mapProfileDeleteError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();
    if (trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }

    switch (code) {
      case 'unauthenticated':
        return 'Hesap silmek icin giris yapmalisiniz.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulasilamadi. Lutfen daha sonra tekrar deneyin.';
      default:
        return 'Hesap silme islemi tamamlanamadi.';
    }
  }

  Future<void> _rollbackAfterSyncFailure({
    required bool deleteCurrentUser,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null && deleteCurrentUser) {
      try {
        await currentUser.delete();
      } on FirebaseAuthException {
        await _signOutSilently();
        return;
      }
    }

    await _signOutSilently();
  }

  Future<void> _signOutSilently() async {
    if (_firebaseAuth.currentUser == null) {
      return;
    }

    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException {
      // Ignore best-effort cleanup failures.
    }
  }

  String _mapAuthSyncFailure(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Sunucu senkron fonksiyonu bulunamadi. Lutfen daha sonra tekrar deneyin.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulasilamadi. Lutfen daha sonra tekrar deneyin.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Rol dogrulamasi basarisiz oldu.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucu yapilandirmasi eksik veya hatali.';
      case 'data-loss':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucudan gecerli rol bilgisi alinamadi.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Kullanici kaydi sunucuya yazilamadi.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Hesap senkronizasyonu tamamlanamadi.';
    }
  }

  String _mapHomeResolverSyncFailure(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Sunucu senkron fonksiyonu bulunamadi. Lutfen tekrar giris yapin.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulasilamadi. Lutfen daha sonra tekrar giris yapin.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Yetki dogrulanamadi. Lutfen tekrar giris yapin.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucu yapilandirmasi eksik veya hatali.';
      case 'data-loss':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucudan gecerli rol bilgisi alinamadi.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucuya baglanirken hata olustu.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Rol bilgisi alinamadi. Lutfen tekrar giris yapin.';
    }
  }
}
