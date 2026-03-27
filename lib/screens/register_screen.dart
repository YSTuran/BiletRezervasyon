import 'package:flutter/material.dart';

//import '../app_routes.dart';
import '../models/enums.dart';
import '../repositories/auth_repository.dart';
import '../view_models/register_view_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final RegisterViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RegisterViewModel();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final fullName = _fullNameController.text.trim();

    try {
      final instruction = await _viewModel.register(
        fullName: fullName,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted || instruction == null) {
        return;
      }
      if (instruction.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(instruction.message!)));
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(instruction.route, (route) => false);
    } on UserMessageException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.normalUser:
        return 'Normal Kullanici';
      case UserRole.companyOfficer:
        return 'Firma Gorevlisi';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Kayit Ol')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Yeni Hesap',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bilgilerinizi girerek kaydolun',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _fullNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Ad Soyad',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                final fullName = value?.trim() ?? '';
                                if (fullName.isEmpty) {
                                  return 'Ad soyad zorunludur';
                                }
                                if (fullName.length < 3) {
                                  return 'Ad soyad en az 3 karakter olmalidir';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'E-posta zorunludur';
                                }
                                if (!email.contains('@') ||
                                    !email.contains('.')) {
                                  return 'Gecerli bir e-posta girin';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<UserRole>(
                              initialValue: _viewModel.selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: UserRole.normalUser,
                                  child: Text(_roleLabel(UserRole.normalUser)),
                                ),
                                DropdownMenuItem(
                                  value: UserRole.companyOfficer,
                                  child: Text(
                                    _roleLabel(UserRole.companyOfficer),
                                  ),
                                ),
                              ],
                              onChanged: _viewModel.isBusy
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _viewModel.updateSelectedRole(value);
                                    },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _viewModel.hidePassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Sifre',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed:
                                      _viewModel.togglePasswordVisibility,
                                  icon: Icon(
                                    _viewModel.hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Sifre zorunludur';
                                }
                                if ((value ?? '').length < 6) {
                                  return 'Sifre en az 6 karakter olmalidir';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _viewModel.hideConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                _register();
                              },
                              decoration: InputDecoration(
                                labelText: 'Sifre Tekrar',
                                prefixIcon: const Icon(
                                  Icons.lock_reset_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: _viewModel
                                      .toggleConfirmPasswordVisibility,
                                  icon: Icon(
                                    _viewModel.hideConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Sifre tekrari zorunludur';
                                }
                                if (value != _passwordController.text) {
                                  return 'Sifreler ayni olmali';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _viewModel.isBusy ? null : _register,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: _viewModel.isBusy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Kayit Ol'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _viewModel.isBusy
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              child: const Text(
                                'Zaten hesabin var mi? Giris yap',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
