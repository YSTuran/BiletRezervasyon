import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/models/company_operations_dashboard.dart';

class CompanyOperationsDashboardViewModel extends BaseViewModel {
  CompanyOperationsDashboardViewModel({required DashboardRepository repository})
    : _repository = repository;

  final DashboardRepository _repository;

  CompanyOperationsDashboard? _dashboard;
  String? _errorMessage;

  CompanyOperationsDashboard? get dashboard => _dashboard;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _dashboard = await _repository.fetchCompanyOperationsDashboard();
      notifyListeners();
    } on DashboardActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
