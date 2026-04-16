import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_routes.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/screens/home_resolver_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/company/data/repositories/company_repository.dart';
import 'features/company/presentation/screens/company_form_screen.dart';
import 'features/company/presentation/screens/company_management_screen.dart';
import 'features/home/presentation/screens/admin_home_screen.dart';
import 'features/home/presentation/screens/company_officer_home_screen.dart';
import 'features/home/presentation/screens/normal_user_home_screen.dart';
import 'features/payment/data/repositories/payment_repository.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/reservation/data/repositories/reservation_repository.dart';
import 'features/trip/data/repositories/trip_repository.dart';
import 'features/trip/presentation/models/trip_route_arguments.dart';
import 'features/trip/presentation/screens/trip_create_screen.dart';
import 'features/trip/presentation/screens/trip_detail_screen.dart';
import 'features/trip/presentation/screens/trip_list_screen.dart';
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

    return MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<CompanyRepository>(create: (_) => CompanyRepository()),
        Provider<TripRepository>(
          create: (context) => TripRepository(
            companyRepository: context.read<CompanyRepository>(),
          ),
        ),
        Provider<ReservationRepository>(create: (_) => ReservationRepository()),
        Provider<PaymentRepository>(create: (_) => PaymentRepository()),
      ],
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
          AppRoutes.companyForm: (context) => const CompanyFormScreen(),
          AppRoutes.companyManagement: (context) =>
              const CompanyManagementScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.tripList:
              final arguments = settings.arguments;
              if (arguments is! TripListArguments) {
                return _buildRouteError(settings, 'Sefer listesi acilamadi.');
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => TripListScreen(arguments: arguments),
              );
            case AppRoutes.tripDetail:
              final arguments = settings.arguments;
              if (arguments is! TripDetailArguments) {
                return _buildRouteError(settings, 'Sefer detayi acilamadi.');
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => TripDetailScreen(arguments: arguments),
              );
            case AppRoutes.tripCreate:
              final arguments = settings.arguments;
              if (arguments is! TripCreateArguments) {
                return _buildRouteError(
                  settings,
                  'Sefer olusturma ekrani acilamadi.',
                );
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => TripCreateScreen(arguments: arguments),
              );
            default:
              return null;
          }
        },
      ),
    );
  }

  Route<dynamic> _buildRouteError(RouteSettings settings, String message) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Yonlendirme Hatasi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
