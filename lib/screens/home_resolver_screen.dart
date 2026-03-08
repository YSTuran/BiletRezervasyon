import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../services/user_sync_service.dart';

class HomeResolverScreen extends StatefulWidget {
  const HomeResolverScreen({super.key});

  @override
  State<HomeResolverScreen> createState() => _HomeResolverScreenState();
}

class _HomeResolverScreenState extends State<HomeResolverScreen> {
  @override
  void initState() {
    super.initState();
    _resolveAndNavigate();
  }

  Future<void> _resolveAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }

    var destinationRoute = AppRoutes.homeNormalUser;
    String? warningMessage;

    try {
      final syncedUser = await UserSyncService.syncSignedInUser(
        preferredFullName: user.displayName,
      );
      destinationRoute = AppRoutes.homeForRole(syncedUser.role);
    } on FirebaseFunctionsException catch (error) {
      warningMessage = _mapSyncWarning(error.code, error.message);
    } catch (_) {
      warningMessage = 'Kullanici rolu alinamadi, varsayilan ekran aciliyor.';
    }

    if (!mounted) {
      return;
    }

    if (warningMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(warningMessage)));
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destinationRoute, (route) => false);
  }

  String _mapSyncWarning(String code, String? message) {
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Rol bilgisi kontrol ediliyor...'),
          ],
        ),
      ),
    );
  }
}
