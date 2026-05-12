import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../company/data/repositories/company_repository.dart';
import '../../../company/domain/models/company.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/models/company_operations_dashboard.dart';

class CompanyOperationsDashboardViewModel extends BaseViewModel {
  CompanyOperationsDashboardViewModel({
    required DashboardRepository dashboardRepository,
    required CompanyRepository companyRepository,
  }) : _dashboardRepository = dashboardRepository,
       _companyRepository = companyRepository;

  final DashboardRepository _dashboardRepository;
  final CompanyRepository _companyRepository;

  CompanyOperationsDashboard? _dashboard;
  Company? _fallbackCompany;
  String? _errorMessage;

  CompanyOperationsDashboard? get dashboard => _dashboard;
  Company? get company => _dashboard?.company ?? _fallbackCompany;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _dashboard = await _dashboardRepository.fetchCompanyOperationsDashboard();
      _fallbackCompany = _dashboard?.company;
      if (_dashboard?.company == null) {
        await _loadFallbackCompany();
      }
    } on DashboardActionException catch (error) {
      _errorMessage = error.message;
      await _loadFallbackCompany();
    } finally {
      setBusy(false);
    }
  }

  Future<void> _loadFallbackCompany() async {
    try {
      _fallbackCompany = await _companyRepository.fetchCurrentOfficerCompany();
    } catch (_) {
      // Keep the dashboard error visible; the fallback is best-effort.
    }
  }
}
