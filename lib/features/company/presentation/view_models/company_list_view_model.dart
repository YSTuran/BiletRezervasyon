import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/company.dart';

class CompanyListViewModel extends BaseViewModel {
  CompanyListViewModel({required CompanyRepository repository})
    : _repository = repository;

  final CompanyRepository _repository;

  List<Company> _companies = const [];

  List<Company> get companies => _companies;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _companies = await _repository.fetchCompanies();
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
