import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/enums.dart';
import '../services/user_sync_service.dart';

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
  UserRole _selectedRole = UserRole.normalUser;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    var destinationRoute = AppRoutes.homeResolver;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentEmail = currentUser?.email?.toLowerCase();

      if (currentUser == null || currentEmail != email.toLowerCase()) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final createdUser = credential.user;
        if (createdUser != null) {
          await createdUser.updateDisplayName(fullName);
        }
      } else if ((currentUser.displayName ?? '').trim() != fullName) {
        await currentUser.updateDisplayName(fullName);
      }

      String? syncWarning;
      try {
        final syncedUser = await UserSyncService.syncSignedInUser(
          preferredFullName: fullName,
          preferredRole: _selectedRole,
        );
        destinationRoute = AppRoutes.homeForRole(syncedUser.role);
      } on FirebaseFunctionsException catch (error) {
        syncWarning = _mapSyncWarning(error.code, error.message);
      }

      if (!mounted) {
        return;
      }
      if (syncWarning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(syncWarning)));
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destinationRoute, (route) => false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapRegisterError(error.code))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  String _mapSyncWarning(String code, String? message) {
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
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Gecerli bir e-posta girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<UserRole>(
                          initialValue: _selectedRole,
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
                              child: Text(_roleLabel(UserRole.companyOfficer)),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Sifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
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
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            _register();
                          },
                          decoration: InputDecoration(
                            labelText: 'Sifre Tekrar',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword = !_hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _hideConfirmPassword
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
                          onPressed: _isLoading ? null : _register,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _isLoading
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
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Zaten hesabin var mi? Giris yap'),
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
  }
}
