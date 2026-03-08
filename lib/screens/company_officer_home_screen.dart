import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';

class CompanyOfficerHomeScreen extends StatelessWidget {
  const CompanyOfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'E-posta bilgisi yok';

    return Scaffold(
      appBar: AppBar(title: const Text('Firma Gorevlisi Ana Sayfa')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu sayfa firma gorevlisine ait home screen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Aktif kullanici: $email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.profile);
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Profile Git'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
