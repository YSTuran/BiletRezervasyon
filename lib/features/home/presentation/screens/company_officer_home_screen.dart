import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../../company/domain/models/company.dart';
import '../../../company/presentation/helpers/company_presentation_helper.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../dashboard/domain/models/company_operations_dashboard.dart';
import '../../../dashboard/presentation/view_models/company_operations_dashboard_view_model.dart';
import '../../../dashboard/presentation/widgets/dashboard_metric_card.dart';
import '../../../dashboard/presentation/widgets/dashboard_section_card.dart';
import '../../../reservation/presentation/helpers/reservation_presentation_helper.dart';
import '../../../reservation/presentation/models/reservation_route_arguments.dart';
import '../../../trip/presentation/helpers/trip_presentation_helper.dart';
import '../../../trip/presentation/models/trip_route_arguments.dart';
import '../view_models/home_view_model.dart';

class CompanyOfficerHomeScreen extends StatelessWidget {
  const CompanyOfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HomeViewModel>(
          create: (context) => HomeViewModel(
            role: UserRole.companyOfficer,
            authRepository: context.read<AuthRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CompanyOperationsDashboardViewModel(
            dashboardRepository: context.read<DashboardRepository>(),
            companyRepository: context.read<CompanyRepository>(),
          )..load(),
        ),
      ],
      child: const _CompanyOperationsHomeView(),
    );
  }
}

class _CompanyOperationsHomeView extends StatefulWidget {
  const _CompanyOperationsHomeView();

  @override
  State<_CompanyOperationsHomeView> createState() =>
      _CompanyOperationsHomeViewState();
}

class _CompanyOperationsHomeViewState
    extends State<_CompanyOperationsHomeView> {
  Future<void> _refresh() async {
    await context.read<CompanyOperationsDashboardViewModel>().load();
  }

  Future<void> _openCompanyForm() async {
    await Navigator.of(context).pushNamed(AppRoutes.companyForm);
    if (!mounted) {
      return;
    }
    await _refresh();
  }

  Future<void> _openTripDetail(String tripId) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.tripDetail,
      arguments: TripDetailArguments(
        role: UserRole.companyOfficer,
        tripId: tripId,
      ),
    );
    if (!mounted) {
      return;
    }
    await _refresh();
  }

  List<Color> _heroColorsFor(Company? company) {
    if (company == null) {
      return const [Color(0xFFDA4453), Color(0xFF89216B)];
    }

    return switch (company.status) {
      ApprovalStatus.approved => const [Color(0xFF11998E), Color(0xFF38EF7D)],
      ApprovalStatus.pending => const [Color(0xFF396AFc), Color(0xFF2948FF)],
      ApprovalStatus.rejected => const [Color(0xFFF7971E), Color(0xFFFF5858)],
    };
  }

  Widget _buildHeroCard(
    BuildContext context,
    HomeViewModel homeViewModel,
    Company? company,
  ) {
    final title = company?.name ?? 'Firma bilgileri eksik';
    final subtitle = company == null
        ? 'Sefer oluşturabilmek için firma adınızı ve ulaşım türünü girmeniz gerekiyor.'
        : company.status == ApprovalStatus.approved
        ? 'Firma onayı tamamlandı. Operasyon panelinden aktif seferleri ve yolcuları takip edebilirsiniz.'
        : company.status == ApprovalStatus.pending
        ? 'Firma kaydınız admin onayında. Onay tamamlanana kadar sefer oluşturamazsınız.'
        : 'Firma kaydınız reddedildi. Bilgileri düzenleyip tekrar gönderebilirsiniz.';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _heroColorsFor(company),
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
            'Firma Operasyon Paneli',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(icon: Icons.email_outlined, label: homeViewModel.email),
              if (company != null)
                _InfoPill(
                  icon: Icons.verified_outlined,
                  label:
                      'Durum: ${CompanyPresentationHelper.approvalLabel(company.status)}',
                ),
              if (company != null)
                _InfoPill(
                  icon: Icons.alt_route_outlined,
                  label:
                      'Ulasim: ${CompanyPresentationHelper.transportLabel(company.transportType)}',
                ),
            ],
          ),
          if ((company?.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Red nedeni: ${company!.rejectionReason}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _openCompanyForm,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF16324F),
                ),
                icon: const Icon(Icons.apartment_outlined),
                label: Text(
                  company == null
                      ? 'Firma Bilgilerini Gir'
                      : 'Firma Bilgilerini Duzenle',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.tripList,
                    arguments: const TripListArguments(
                      role: UserRole.companyOfficer,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Seferlere Git'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(CompanyOperationsStats stats) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        DashboardMetricCard(
          title: 'Doluluk Orani',
          value: '%${stats.overallOccupancyRatePercent}',
          subtitle: 'Aktif ve yaklasan seferler',
          icon: Icons.pie_chart_outline,
          colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        DashboardMetricCard(
          title: 'Yaklasan Sefer',
          value: '${stats.upcomingTripCount}',
          subtitle: 'Henuz kalkmamis sefer',
          icon: Icons.event_available_outlined,
          colors: const [Color(0xFF396AFc), Color(0xFF2948FF)],
        ),
        DashboardMetricCard(
          title: 'Yoldaki Sefer',
          value: '${stats.activeTripCount}',
          subtitle: 'Su anda devam eden',
          icon: Icons.local_shipping_outlined,
          colors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        ),
        DashboardMetricCard(
          title: 'Bekleyen Talep',
          value: '${stats.pendingReservationCount}',
          subtitle: 'Onay bekleyen rezervasyon',
          icon: Icons.pending_actions_outlined,
          colors: const [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
        ),
        DashboardMetricCard(
          title: 'Yolcu Sayisi',
          value: '${stats.passengerCount}',
          subtitle: 'Listeye yansiyan aktif yolcu',
          icon: Icons.groups_2_outlined,
          colors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
        ),
      ],
    );
  }

  Widget _buildUpcomingTripsSection(
    BuildContext context,
    List<CompanyOperationsTripSnapshot> trips,
  ) {
    if (trips.isEmpty) {
      return const Text('Yaklasan veya yolda olan onayli sefer bulunmuyor.');
    }

    return Column(
      children: trips.map((trip) {
        final visualStyle = TripPresentationHelper.visualStyleForValues(
          status: trip.status,
          departureAt: trip.departureAt,
          arrivalAt: trip.arrivalAt,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openTripDetail(trip.tripId),
            child: Container(
              decoration: BoxDecoration(
                color: visualStyle.backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: visualStyle.borderColor, width: 1.5),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: visualStyle.borderColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          visualStyle.label,
                          style: TextStyle(
                            color: visualStyle.foregroundColor == Colors.white
                                ? Colors.white
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        trip.tripCode,
                        style: TextStyle(
                          color: visualStyle.foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${trip.origin} -> ${trip.destination}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: visualStyle.foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kalkış: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                    style: TextStyle(color: visualStyle.foregroundColor),
                  ),
                  Text(
                    'Doluluk: %${trip.occupancyRatePercent} (${trip.occupiedSeatCount}/${trip.seatCapacity})',
                    style: TextStyle(color: visualStyle.foregroundColor),
                  ),
                  Text(
                    'Biletlenen yolcu: ${trip.paidPassengerCount}',
                    style: TextStyle(color: visualStyle.foregroundColor),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPassengerManifest(
    BuildContext context,
    List<PassengerManifestEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const Text('Aktif seferler için gösterilecek yolcu bulunmuyor.');
    }

    return Column(
      children: entries.map((entry) {
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
              entry.passengerName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.origin} -> ${entry.destination}'),
                  Text('Sefer: ${entry.tripCode}'),
                  Text('Koltuk: ${entry.seatNumber}'),
                  Text(
                    'Durum: ${ReservationPresentationHelper.statusLabel(entry.reservationStatus)}',
                  ),
                  Text(
                    'Kalkış: ${TripPresentationHelper.formatDateTime(entry.departureAt)}',
                  ),
                  Text(entry.passengerEmail),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return DashboardSectionCard(
      title: 'Hızlı İşlem',
      subtitle: 'Operasyon akışına hızlı geçişler',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.tripList,
                arguments: const TripListArguments(
                  role: UserRole.companyOfficer,
                ),
              );
            },
            icon: const Icon(Icons.route_outlined),
            label: const Text('Seferlerim'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.reservationList,
                arguments: const ReservationListArguments(
                  role: UserRole.companyOfficer,
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Rezervasyon Talepleri'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
            icon: const Icon(Icons.person_outline),
            label: const Text('Profil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.read<HomeViewModel>();
    final viewModel = context.watch<CompanyOperationsDashboardViewModel>();
    final dashboard = viewModel.dashboard;
    final company = viewModel.company;

    if (viewModel.isBusy && dashboard == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(title: const Text('Firma Operasyon Paneli')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeroCard(context, homeViewModel, company),
            if (viewModel.errorMessage != null && dashboard == null) ...[
              const SizedBox(height: 16),
              DashboardSectionCard(
                title: 'Panel Yüklenemedi',
                child: Text(viewModel.errorMessage!),
              ),
            ],
            const SizedBox(height: 18),
            if (company?.status == ApprovalStatus.approved &&
                dashboard != null) ...[
              _buildMetrics(dashboard.stats),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Yaklaşan ve Aktif Seferler',
                subtitle: 'Doluluk ve biletlenen yolcu bilgisini anlık görün.',
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.tripList,
                      arguments: const TripListArguments(
                        role: UserRole.companyOfficer,
                      ),
                    );
                  },
                  child: const Text('Tümünü Aç'),
                ),
                child: _buildUpcomingTripsSection(
                  context,
                  dashboard.upcomingTrips,
                ),
              ),
              const SizedBox(height: 18),
              DashboardSectionCard(
                title: 'Yolcu Listesi',
                subtitle:
                    'Onaylanmış ve ödemesi tamamlanmış aktif yolcular görünür.',
                child: _buildPassengerManifest(
                  context,
                  dashboard.passengerManifest,
                ),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
