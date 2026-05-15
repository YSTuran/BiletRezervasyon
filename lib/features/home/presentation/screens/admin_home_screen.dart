import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../company/presentation/helpers/company_presentation_helper.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../dashboard/domain/models/admin_dashboard.dart';
import '../../../dashboard/presentation/view_models/admin_dashboard_view_model.dart';
import '../../../dashboard/presentation/widgets/dashboard_metric_card.dart';
import '../../../dashboard/presentation/widgets/dashboard_section_card.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../reservation/presentation/models/reservation_route_arguments.dart';
import '../../../trip/presentation/helpers/trip_presentation_helper.dart';
import '../../../trip/presentation/models/trip_route_arguments.dart';
import '../view_models/home_view_model.dart';
import '../widgets/home_navigation_card.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HomeViewModel>(
          create: (context) => HomeViewModel(
            role: UserRole.admin,
            authRepository: context.read<AuthRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminDashboardViewModel(
            repository: context.read<DashboardRepository>(),
          )..load(),
        ),
      ],
      child: const _AdminDashboardHomeView(),
    );
  }
}

class _AdminDashboardHomeView extends StatefulWidget {
  const _AdminDashboardHomeView();

  @override
  State<_AdminDashboardHomeView> createState() =>
      _AdminDashboardHomeViewState();
}

class _AdminDashboardHomeViewState extends State<_AdminDashboardHomeView> {
  Future<void> _refresh() async {
    await context.read<AdminDashboardViewModel>().load();
  }

  Widget _buildHeroCard(BuildContext context, HomeViewModel homeViewModel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4350), Color(0xFFA43931)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Paneli',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Onay, satış ve red akışları tek panelde',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bekleyen firma, sefer ve rezervasyonları hızlı izleyebilir; toplam satış ve red nedenlerini tek bakışta görebilirsiniz.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  homeViewModel.email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(AdminDashboardSummary summary) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        DashboardMetricCard(
          title: 'Bekleyen Firma',
          value: '${summary.pendingCompanyCount}',
          subtitle: 'Onay sırasında',
          icon: Icons.apartment_outlined,
          colors: const [Color(0xFF396AFc), Color(0xFF2948FF)],
        ),
        DashboardMetricCard(
          title: 'Bekleyen Sefer',
          value: '${summary.pendingTripCount}',
          subtitle: 'Admin kararı bekliyor',
          icon: Icons.route_outlined,
          colors: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
        ),
        DashboardMetricCard(
          title: 'Bekleyen Rezervasyon',
          value: '${summary.pendingReservationCount}',
          subtitle: 'Firma kararı bekliyor',
          icon: Icons.pending_actions_outlined,
          colors: const [Color(0xFF654EA3), Color(0xFFEAafc8)],
        ),
        DashboardMetricCard(
          title: 'Tamamlanan Ödeme',
          value: '${summary.paidPaymentCount}',
          subtitle: 'Başarılı ödeme adedi',
          icon: Icons.payments_outlined,
          colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        DashboardMetricCard(
          title: 'Toplam Satış',
          value: TripPresentationHelper.formatPrice(summary.totalSalesMinor),
          subtitle: '${summary.paidReservationCount} ödemeli rezervasyon',
          icon: Icons.stacked_line_chart_outlined,
          colors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        ),
      ],
    );
  }

  Widget _buildPendingCompanies(List<PendingCompanyPreview> companies) {
    if (companies.isEmpty) {
      return const Text('Bekleyen firma bulunmuyor.');
    }

    return Column(
      children: companies.map((company) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE3EF)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            title: Text(
              company.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CompanyPresentationHelper.transportLabel(
                      company.transportType,
                    ),
                  ),
                  Text(company.officerName),
                  Text(company.officerEmail),
                  Text(
                    'Talep: ${TripPresentationHelper.formatDateTime(company.createdAt)}',
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingTrips(
    BuildContext context,
    List<PendingTripPreview> trips,
  ) {
    if (trips.isEmpty) {
      return const Text('Bekleyen sefer bulunmuyor.');
    }

    return Column(
      children: trips.map((trip) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1C187)),
          ),
          child: ListTile(
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.tripDetail,
                arguments: TripDetailArguments(
                  role: UserRole.admin,
                  tripId: trip.id,
                ),
              );
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            title: Text(
              '${trip.origin} -> ${trip.destination}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kod: ${trip.tripCode}'),
                  Text('Firma: ${trip.companyName}'),
                  Text(
                    'Tür: ${TripPresentationHelper.transportLabel(trip.transportType)}',
                  ),
                  Text(
                    'Kalkış: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingReservations(List<PendingReservationPreview> items) {
    if (items.isEmpty) {
      return const Text('Bekleyen rezervasyon bulunmuyor.');
    }

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFBDD0FF)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            title: Text(
              '${item.origin} -> ${item.destination}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sefer: ${item.tripCode}'),
                  Text('Koltuk: ${item.seatNumber}'),
                  Text('Firma: ${item.companyName}'),
                  Text(
                    'Talep: ${TripPresentationHelper.formatDateTime(item.requestedAt)}',
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRejectionReasons(List<DashboardRejectionReason> items) {
    if (items.isEmpty) {
      return const Text('Kayıtlı red nedeni bulunmuyor.');
    }

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EA),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF7C1AF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.category}: ${item.subject}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(item.reason),
              const SizedBox(height: 8),
              Text(
                TripPresentationHelper.formatDateTime(item.occurredAt),
                style: const TextStyle(color: Color(0xFF76504A)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              icon: Icons.apartment_outlined,
              title: 'Firmaları Yönet',
              subtitle: 'Firma başvurularını inceleyin',
              colors: const [Color(0xFF396AFC), Color(0xFF20BDFF)],
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.companyManagement);
              },
            ),
            HomeNavigationItem(
              icon: Icons.route_outlined,
              title: 'Tüm Seferler',
              subtitle: 'Sefer onaylarını ve kayıtlarını görün',
              colors: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.tripList,
                  arguments: const TripListArguments(role: UserRole.admin),
                );
              },
            ),
            HomeNavigationItem(
              icon: Icons.receipt_long_outlined,
              title: 'Rezervasyonlar',
              subtitle: 'Rezervasyon akışını takip edin',
              colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.reservationList,
                  arguments: const ReservationListArguments(
                    role: UserRole.admin,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.read<HomeViewModel>();
    final viewModel = context.watch<AdminDashboardViewModel>();
    final dashboard = viewModel.dashboard;

    if (viewModel.isBusy && dashboard == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: const [NotificationBellButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeroCard(context, homeViewModel),
            if (viewModel.errorMessage != null && dashboard == null) ...[
              const SizedBox(height: 16),
              DashboardSectionCard(
                title: 'Panel Yüklenemedi',
                child: Text(viewModel.errorMessage!),
              ),
            ],
            if (dashboard != null) ...[
              const SizedBox(height: 18),
              _buildMetrics(dashboard.summary),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Bekleyen Firmalar',
                subtitle: 'İlk onay sırasındaki firma talepleri',
                child: _buildPendingCompanies(dashboard.pendingCompanies),
              ),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Bekleyen Seferler',
                subtitle: 'Admin kararı bekleyen son sefer talepleri',
                child: _buildPendingTrips(context, dashboard.pendingTrips),
              ),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Bekleyen Rezervasyon Özetleri',
                subtitle:
                    'Firma işlemini bekleyen son rezervasyon taleplerinin özeti',
                child: _buildPendingReservations(dashboard.pendingReservations),
              ),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Son Red Nedenleri',
                subtitle: 'Firmalar, seferler ve rezervasyonlardan son notlar',
                child: _buildRejectionReasons(dashboard.rejectionReasons),
              ),
              const SizedBox(height: 18),
            ],
            _buildActionPanel(context),
          ],
        ),
      ),
    );
  }
}
