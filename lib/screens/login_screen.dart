import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../services/user_sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      var destinationRoute = AppRoutes.homeResolver;
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String? syncWarning;
      try {
        final syncedUser = await UserSyncService.syncSignedInUser(
          preferredFullName: credential.user?.displayName,
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
      ).showSnackBar(SnackBar(content: Text(_mapLoginError(error.code))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          'Bilet Rezervasyon',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hesabiniza giris yapin',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
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
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            _login();
                          },
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
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _login,
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
                                : const Text('Giris Yap'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.register);
                                },
                          child: const Text('Hesabin yok mu? Kayit ol'),
                        ),
                        const SizedBox(height: 4), //Text
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
