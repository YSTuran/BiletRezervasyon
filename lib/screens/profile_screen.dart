import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.userEmail, this.onLogout, super.key});

  final String? userEmail;
  final Future<void> Function()? onLogout;

  String _resolveEmail() {
    final passedEmail = userEmail?.trim() ?? '';
    if (passedEmail.isNotEmpty) {
      return passedEmail;
    }

    final authEmail = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (authEmail.isNotEmpty) {
      return authEmail;
    }

    return 'E-posta bilgisi yok';
  }

  Future<void> _defaultLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _logout(BuildContext context) async {
    if (onLogout != null) {
      await onLogout!.call();
      return;
    }
    await _defaultLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    final email = _resolveEmail();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        email.isNotEmpty
                            ? email.substring(0, 1).toUpperCase()
                            : '?',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await _logout(context);
                        } on FirebaseAuthException catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cikis yapilamadi: ${error.code}'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Cikis Yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
