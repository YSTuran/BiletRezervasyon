import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_routes.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/screens/home_resolver_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/home/presentation/screens/admin_home_screen.dart';
import 'features/home/presentation/screens/company_officer_home_screen.dart';
import 'features/home/presentation/screens/normal_user_home_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseEnabled = await _initializeFirebase();
  runApp(MainApp(firebaseEnabled: firebaseEnabled));
}

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } on UnsupportedError {
    return false;
  }
}

class MainApp extends StatelessWidget {
  const MainApp({required this.firebaseEnabled, super.key});

  final bool firebaseEnabled;

  @override
  Widget build(BuildContext context) {
    if (!firebaseEnabled) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase bu platform icin ayarli degil. Android veya iOS hedefinde calistirin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );
    }

    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Provider<AuthRepository>(
      create: (_) => AuthRepository(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bilet Rezervasyon',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        initialRoute: isLoggedIn ? AppRoutes.homeResolver : AppRoutes.login,
        routes: {
          AppRoutes.login: (context) => const LoginScreen(),
          AppRoutes.register: (context) => const RegisterScreen(),
          AppRoutes.homeResolver: (context) => const HomeResolverScreen(),
          AppRoutes.homeNormalUser: (context) => const NormalUserHomeScreen(),
          AppRoutes.homeCompanyOfficer: (context) =>
              const CompanyOfficerHomeScreen(),
          AppRoutes.homeAdmin: (context) => const AdminHomeScreen(),
          AppRoutes.profile: (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
