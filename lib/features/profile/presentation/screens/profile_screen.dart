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

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();
  String? _seededEmail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<ProfileViewModel>();
    if (_seededEmail != viewModel.email) {
      _seededEmail = viewModel.email;
      _nameController.text = viewModel.fullName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

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

  Future<void> _saveName(BuildContext context) async {
    if (!_nameFormKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<ProfileViewModel>().updateFullName(
        _nameController.text,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ad-soyad guncellendi.')));
    } on UserMessageException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<ProfileViewModel>().changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sifre guncellendi.')));
    } on UserMessageException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = _deletePasswordController.text;
    if (password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabi silmek icin sifrenizi girin.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hesabi Sil'),
          content: const Text(
            'Bu islem oturumunuzu kapatir ve hesabinizi kalici olarak siler. Devam etmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hesabi Sil'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    try {
      final route = await context.read<ProfileViewModel>().deleteAccount(
        currentPassword: password,
      );
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
    }
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF396AFC), Color(0xFF20BDFF)],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          viewModel.email.substring(0, 1).toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.fullName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              viewModel.email,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context: context,
                  title: 'Ad-Soyad',
                  icon: Icons.badge_outlined,
                  children: [
                    Form(
                      key: _nameFormKey,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad-soyad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Ad-soyad zorunludur';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: viewModel.isBusy
                          ? null
                          : () {
                              _saveName(context);
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Ad-Soyadi Kaydet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context: context,
                  title: 'Sifre Degistir',
                  icon: Icons.lock_reset_outlined,
                  children: [
                    Form(
                      key: _passwordFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mevcut sifre',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Mevcut sifre zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Yeni sifre',
                              prefixIcon: Icon(Icons.password_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'En az 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Yeni sifre tekrar',
                              prefixIcon: Icon(Icons.done_all_outlined),
                            ),
                            validator: (value) {
                              if (value != _newPasswordController.text) {
                                return 'Sifreler eslesmiyor';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: viewModel.isBusy
                          ? null
                          : () {
                              _changePassword(context);
                            },
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Sifreyi Guncelle'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context: context,
                  title: 'Hesap Islemleri',
                  icon: Icons.manage_accounts_outlined,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: viewModel.isBusy
                          ? null
                          : () {
                              _logout(context);
                            },
                      icon: const Icon(Icons.logout),
                      label: const Text('Cikis Yap'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deletePasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Hesap silme sifresi',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: viewModel.isBusy
                          ? null
                          : () {
                              _deleteAccount(context);
                            },
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Hesabi Sil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
