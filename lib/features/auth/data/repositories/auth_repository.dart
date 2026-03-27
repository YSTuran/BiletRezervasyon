import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      return _syncAfterAuth(preferredFullName: credential.user?.displayName);
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

      if (currentUser == null ||
          currentEmail != normalizedEmail.toLowerCase()) {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
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
    } on FirebaseFunctionsException catch (error) {
      return NavigationInstruction(
        route: AppRoutes.homeNormalUser,
        message: _mapHomeResolverSyncWarning(error.code, error.message),
      );
    } catch (_) {
      return const NavigationInstruction(
        route: AppRoutes.homeNormalUser,
        message: 'Kullanici rolu alinamadi, varsayilan ekran aciliyor.',
      );
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

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

  Future<NavigationInstruction> _syncAfterAuth({
    String? preferredFullName,
    UserRole? preferredRole,
  }) async {
    var destinationRoute = AppRoutes.homeResolver;
    String? warningMessage;

    try {
      final syncedUser = await UserSyncService.syncSignedInUser(
        preferredFullName: preferredFullName,
        preferredRole: preferredRole,
      );
      destinationRoute = AppRoutes.homeForRole(syncedUser.role);
    } on FirebaseFunctionsException catch (error) {
      warningMessage = _mapAuthSyncWarning(error.code, error.message);
    }

    return NavigationInstruction(
      route: destinationRoute,
      message: warningMessage,
    );
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

  String _mapAuthSyncWarning(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Hesap acildi ancak PostgreSQL senkron fonksiyonu bulunamadi.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Hesap acildi ancak PostgreSQL baglantisi su an kullanilamiyor.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Hesap acildi ancak PostgreSQL yetkilendirmesi basarisiz oldu.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Hesap acildi ancak sunucu yapilandirmasi eksik.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Hesap acildi ancak PostgreSQL baglantisi basarisiz oldu.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Hesap acildi ancak PostgreSQL senkronizasyonu tamamlanamadi.';
    }
  }

  String _mapHomeResolverSyncWarning(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'PostgreSQL senkron fonksiyonu bulunamadi, varsayilan ekran aciliyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulasilamadi, varsayilan ekran aciliyor.';
      case 'permission-denied':
      case 'unauthenticated':
        return 'Yetki dogrulanamadi, varsayilan ekran aciliyor.';
      case 'failed-precondition':
        if (trimmedMessage.isNotEmpty) {
          return '$trimmedMessage (kod: $code)';
        }
        return 'Sunucu yapilandirmasi eksik, varsayilan ekran aciliyor.';
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return '$trimmedMessage (kod: $code)';
        }
        return 'PostgreSQL baglantisi basarisiz, varsayilan ekran aciliyor.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return '$trimmedMessage (kod: $code)';
        }
        return 'Rol bilgisi alinamadi, varsayilan ekran aciliyor.';
    }
  }
}
