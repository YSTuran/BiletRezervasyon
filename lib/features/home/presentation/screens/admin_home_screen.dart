import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../view_models/home_view_model.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<HomeViewModel>(
      create: (context) => HomeViewModel(
        role: UserRole.admin,
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _RoleHomeView(),
    );
  }
}

class _RoleHomeView extends StatelessWidget {
  const _RoleHomeView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<HomeViewModel>();

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
