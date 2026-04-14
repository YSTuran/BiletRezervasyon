import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../../company/domain/models/company.dart';
import '../../../company/presentation/helpers/company_presentation_helper.dart';
import '../../../trip/presentation/models/trip_route_arguments.dart';
import '../view_models/home_view_model.dart';

class CompanyOfficerHomeScreen extends StatelessWidget {
  const CompanyOfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<HomeViewModel>(
      create: (context) => HomeViewModel(
        role: UserRole.companyOfficer,
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _RoleHomeView(),
    );
  }
}

class _RoleHomeView extends StatefulWidget {
  const _RoleHomeView();

  @override
  State<_RoleHomeView> createState() => _RoleHomeViewState();
}

class _RoleHomeViewState extends State<_RoleHomeView> {
  Future<Company?>? _companyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _companyFuture ??= _loadCompany();
  }

  Future<Company?> _loadCompany() {
    return context.read<CompanyRepository>().fetchCurrentOfficerCompany();
  }

  Future<void> _openCompanyForm() async {
    await Navigator.of(context).pushNamed(AppRoutes.companyForm);
    if (!mounted) {
      return;
    }

    setState(() {
      _companyFuture = _loadCompany();
    });
  }

  Widget _buildCompanyCard(
    BuildContext context,
    AsyncSnapshot<Company?> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Firma bilgileri kontrol ediliyor...')),
            ],
          ),
        ),
      );
    }

    final company = snapshot.data;
    if (company == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Firma bilgileri eksik.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sefer olusturabilmek icin once firma adinizi ve ulasim turunu girmeniz gerekiyor.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openCompanyForm,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Firma Bilgilerini Gir'),
              ),
            ],
          ),
        ),
      );
    }

    final rejectionReason = (company.rejectionReason ?? '').trim();
    final buttonLabel = switch (company.status) {
      ApprovalStatus.pending => 'Bilgileri Guncelle',
      ApprovalStatus.approved => 'Firma Bilgilerini Duzenle',
      ApprovalStatus.rejected => 'Tekrar Gonder',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(company.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Durum: ${CompanyPresentationHelper.approvalLabel(company.status)}',
            ),
            Text(
              'Ulasim: ${CompanyPresentationHelper.transportLabel(company.transportType)}',
            ),
            if (company.status == ApprovalStatus.pending) ...[
              const SizedBox(height: 8),
              const Text(
                'Admin onayi tamamlanana kadar yeni sefer olusturamazsiniz.',
              ),
            ],
            if (rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Red nedeni: $rejectionReason',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openCompanyForm,
              icon: const Icon(Icons.business_outlined),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.appBarTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktif kullanici: ${viewModel.email}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FutureBuilder<Company?>(
                  future: _companyFuture,
                  builder: _buildCompanyCard,
                ),
                const SizedBox(height: 20),
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
                  label: Text(viewModel.tripButtonLabel),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openCompanyForm,
                  icon: const Icon(Icons.apartment_outlined),
                  label: const Text('Firma Bilgileri'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.profile);
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profile Git'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
