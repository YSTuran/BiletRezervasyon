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
        message: 'Oturum doğrulanamadı. Lütfen tekrar giriş yapın.',
      );
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String? resolveCurrentUserId() => _firebaseAuth.currentUser?.uid;

  Future<UserRole> resolveCurrentUserRole() async {
    final syncedUser = await UserSyncService.syncSignedInUser(
      preferredFullName: _firebaseAuth.currentUser?.displayName,
    );
    return syncedUser.role;
  }

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

    return 'Yeni Kullanıcı';
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
      throw const UserMessageException('Aktif kullanıcı bulunamadı.');
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
      throw const UserMessageException('Mevcut şifre zorunludur.');
    }
    if (newPassword.length < 6) {
      throw const UserMessageException(
        'Yeni şifre en az 6 karakter olmalıdır.',
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
      throw const UserMessageException('Hesabı silmek için şifrenizi girin.');
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
        'Hesap senkronizasyonu tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  User _requirePasswordUser() {
    final user = _firebaseAuth.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw const UserMessageException(
        'Aktif e-posta/şifre kullanıcısı bulunamadı.',
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
        return 'E-posta formatı geçersiz.';
      case 'user-disabled':
        return 'Bu kullanıcı devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu e-posta için hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnterneti kontrol edin.';
      default:
        return 'Giriş yapılamadı: $code';
    }
  }

  String _mapRegisterError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var.';
      case 'invalid-email':
        return 'E-posta formatı geçersiz.';
      case 'weak-password':
        return 'Şifre güçsüz. En az 6 karakter kullanın.';
      case 'operation-not-allowed':
        return 'E-posta/şifre kaydı şu an kapalı.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnterneti kontrol edin.';
      default:
        return 'Kayıt tamamlanamadı: $code';
    }
  }

  String _mapProfileAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mevcut şifre hatalı.';
      case 'weak-password':
        return 'Yeni şifre güçsüz. En az 6 karakter kullanın.';
      case 'requires-recent-login':
        return 'Bu işlem için tekrar giriş yapmanız gerekiyor.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnterneti kontrol edin.';
      default:
        return 'Profil işlemi tamamlanamadı: $code';
    }
  }

  String _mapProfileDeleteError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();
    if (trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }

    switch (code) {
      case 'unauthenticated':
        return 'Hesap silmek için giriş yapmalısınız.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      default:
        return 'Hesap silme işlemi tamamlanamadı.';
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
        return 'Sunucu senkron fonksiyonu bulunamadı. Lütfen daha sonra tekrar deneyin.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Rol doğrulaması başarısız oldu.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucu yapılandırması eksik veya hatalı.';
      case 'data-loss':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucudan geçerli rol bilgisi alınamadı.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Kullanıcı kaydı sunucuya yazılamadı.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Hesap senkronizasyonu tamamlanamadı.';
    }
  }

  String _mapHomeResolverSyncFailure(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Sunucu senkron fonksiyonu bulunamadı. Lütfen tekrar giriş yapın.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar giriş yapın.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Yetki doğrulanamadı. Lütfen tekrar giriş yapın.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucu yapılandırması eksik veya hatalı.';
      case 'data-loss':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucudan geçerli rol bilgisi alınamadı.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Sunucuya bağlanırken hata oluştu.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Rol bilgisi alınamadı. Lütfen tekrar giriş yapın.';
    }
  }
}
