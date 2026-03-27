import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/enums.dart';
import '../view_models/home_view_model.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = HomeViewModel(role: UserRole.admin);

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.appBarTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Aktif kullanici: ${viewModel.email}',
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
