import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/models/admin_dashboard.dart';

class AdminDashboardViewModel extends BaseViewModel {
  AdminDashboardViewModel({required DashboardRepository repository})
    : _repository = repository;

  final DashboardRepository _repository;

  AdminDashboard? _dashboard;
  String? _errorMessage;

  AdminDashboard? get dashboard => _dashboard;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _dashboard = await _repository.fetchAdminDashboard();
      notifyListeners();
    } on DashboardActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
