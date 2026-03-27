import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../view_models/profile_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.userEmail, this.onLogout, super.key});

  final String? userEmail;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileViewModel(
        userEmail: userEmail,
        onLogout: onLogout,
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  Future<void> _logout(BuildContext context) async {
    final viewModel = context.read<ProfileViewModel>();

    try {
      final route = await viewModel.logout();
      if (!context.mounted || route == null) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    } on UserMessageException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cikis yapilamadi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileViewModel>();

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
                        viewModel.email.substring(0, 1).toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      viewModel.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: viewModel.isBusy
                          ? null
                          : () {
                              _logout(context);
                            },
                      icon: const Icon(Icons.logout),
                      label: viewModel.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cikis Yap'),
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
