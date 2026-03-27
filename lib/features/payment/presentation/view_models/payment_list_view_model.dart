import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentListViewModel extends BaseViewModel {
  PaymentListViewModel({required PaymentRepository repository})
    : _repository = repository;

  final PaymentRepository _repository;

  List<Payment> _payments = const [];

  List<Payment> get payments => _payments;

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _payments = await _repository.fetchPayments();
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
