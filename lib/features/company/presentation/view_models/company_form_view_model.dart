import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/company.dart';

class CompanyFormViewModel extends BaseViewModel {
  CompanyFormViewModel({required CompanyRepository repository})
    : _repository = repository;

  final CompanyRepository _repository;

  Company? _company;
  String? _errorMessage;
  TransportType _transportType = TransportType.bus;

  Company? get company => _company;
  String? get errorMessage => _errorMessage;
  TransportType get transportType => _transportType;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _company = await _repository.fetchCurrentOfficerCompany();
      _transportType = _company?.transportType ?? TransportType.bus;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Firma bilgileri yüklenemedi.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  void updateTransportType(TransportType transportType) {
    if (_transportType == transportType) {
      return;
    }
    _transportType = transportType;
    notifyListeners();
  }

  Future<Company?> saveCompany(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const CompanyFormException('Firma adi zorunludur.');
    }

    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      final savedCompany = await _repository.saveCurrentOfficerCompany(
        name: trimmedName,
        transportType: _transportType,
      );
      _company = savedCompany;
      notifyListeners();
      return savedCompany;
    } on CompanyActionException catch (error) {
      throw CompanyFormException(error.message);
    } finally {
      setBusy(false);
    }
  }
}

class CompanyFormException implements Exception {
  const CompanyFormException(this.message);

  final String message;
}
