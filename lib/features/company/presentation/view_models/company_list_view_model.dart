import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/company.dart';

class CompanyListViewModel extends BaseViewModel {
  CompanyListViewModel({required CompanyRepository repository})
    : _repository = repository;

  final CompanyRepository _repository;

  List<Company> _companies = const [];
  String? _errorMessage;
  ApprovalStatus _selectedStatus = ApprovalStatus.pending;

  List<Company> get companies => _companies;
  String? get errorMessage => _errorMessage;
  ApprovalStatus get selectedStatus => _selectedStatus;
  bool get showsReviewActions => _selectedStatus == ApprovalStatus.pending;

  String get emptyMessage => switch (_selectedStatus) {
    ApprovalStatus.pending => 'Onay bekleyen firma bulunmuyor.',
    ApprovalStatus.approved => 'Onaylanmis firma bulunmuyor.',
    ApprovalStatus.rejected => 'Reddedilen firmalar listelenmiyor.',
  };

  void updateSelectedStatus(ApprovalStatus status) {
    if (status == ApprovalStatus.rejected || _selectedStatus == status) {
      return;
    }
    _selectedStatus = status;
    notifyListeners();
  }

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _companies = await _repository.fetchCompanies(status: _selectedStatus);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Firma listesi su anda yuklenemedi.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  Future<void> approveCompany(String companyId) async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      await _repository.approveCompany(companyId);
      _companies = await _repository.fetchCompanies(status: _selectedStatus);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Firma onaylanamadi.';
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<void> rejectCompany(String companyId, String rejectionReason) async {
    final trimmedReason = rejectionReason.trim();
    if (trimmedReason.isEmpty) {
      throw const CompanyReviewException('Red nedeni zorunludur.');
    }

    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      await _repository.rejectCompany(
        companyId: companyId,
        rejectionReason: trimmedReason,
      );
      _companies = await _repository.fetchCompanies(status: _selectedStatus);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Firma reddedilemedi.';
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }
}

class CompanyReviewException implements Exception {
  const CompanyReviewException(this.message);

  final String message;
}
