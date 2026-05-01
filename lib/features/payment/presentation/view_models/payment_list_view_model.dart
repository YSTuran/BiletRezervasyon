import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentListViewModel extends BaseViewModel {
  PaymentListViewModel({
    required PaymentRepository repository,
    required this.role,
  }) : _repository = repository;

  final PaymentRepository _repository;
  final UserRole role;

  List<Payment> _payments = const [];
  String? _errorMessage;

  List<Payment> get payments => _payments;
  String? get errorMessage => _errorMessage;

  String get title => switch (role) {
    UserRole.normalUser => 'Odemelerim',
    UserRole.companyOfficer => 'Odeme Kayitlari',
    UserRole.admin => 'Tum Odemeler',
  };

  String get emptyMessage => switch (role) {
    UserRole.normalUser => 'Henuz bir odeme kaydiniz bulunmuyor.',
    UserRole.companyOfficer => 'Sirket seferleri icin odeme kaydi bulunmuyor.',
    UserRole.admin => 'Gosterilecek odeme kaydi bulunmuyor.',
  };

  bool canOpenCheckout(Payment payment) {
    return role == UserRole.normalUser &&
        payment.reservationStatus == ReservationStatus.approved &&
        (payment.status == PaymentStatus.pending ||
            payment.status == PaymentStatus.failed);
  }

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _payments = await _repository.fetchPayments();
      notifyListeners();
    } on PaymentActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
