import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../payment/presentation/models/payment_route_arguments.dart';
import '../../../reservation/presentation/models/reservation_route_arguments.dart';
import '../../../trip/presentation/models/trip_route_arguments.dart';
import '../view_models/home_view_model.dart';
import '../widgets/home_navigation_card.dart';

class NormalUserHomeScreen extends StatelessWidget {
  const NormalUserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<HomeViewModel>(
      create: (context) => HomeViewModel(
        role: UserRole.normalUser,
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
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(title: Text(viewModel.appBarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF396AFC), Color(0xFF20BDFF)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.appBarTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  viewModel.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.94),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Aktif kullanıcı: ${viewModel.email}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'İşlemler',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          HomeNavigationGrid(
            items: [
              HomeNavigationItem(
                icon: Icons.map_outlined,
                title: viewModel.tripButtonLabel,
                subtitle: 'Yaklaşan seferleri inceleyin',
                colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.tripList,
                    arguments: const TripListArguments(
                      role: UserRole.normalUser,
                    ),
                  );
                },
              ),
              HomeNavigationItem(
                icon: Icons.confirmation_number_outlined,
                title: 'Rezervasyonlarım',
                subtitle: 'Taleplerinizi ve durumlarını görün',
                colors: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.reservationList,
                    arguments: const ReservationListArguments(
                      role: UserRole.normalUser,
                    ),
                  );
                },
              ),
              HomeNavigationItem(
                icon: Icons.credit_card_outlined,
                title: 'Ödemelerim',
                subtitle: 'Ödeme kayıtlarınızı takip edin',
                colors: const [Color(0xFF654EA3), Color(0xFFEAafc8)],
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.paymentList,
                    arguments: const PaymentListArguments(
                      role: UserRole.normalUser,
                    ),
                  );
                },
              ),
              HomeNavigationItem(
                icon: Icons.person_outline,
                title: 'Profil',
                subtitle: 'Hesap bilgilerinizi yönetin',
                colors: const [Color(0xFF1D4350), Color(0xFFA43931)],
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.profile);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
