import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentCheckoutViewModel extends BaseViewModel {
  PaymentCheckoutViewModel({
    required PaymentRepository repository,
    required this.reservationId,
  }) : _repository = repository;

  final PaymentRepository _repository;
  final String reservationId;

  Payment? _payment;
  String? _errorMessage;
  bool _hasLoaded = false;

  Payment? get payment => _payment;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;
  bool get canSubmitPayment =>
      _payment?.reservationStatus == ReservationStatus.approved &&
      (_payment?.status == PaymentStatus.pending ||
          _payment?.status == PaymentStatus.failed);

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    setBusy(true);
    try {
      _errorMessage = null;
      _payment = await _repository.fetchReservationPayment(
        reservationId: reservationId,
      );
      _hasLoaded = true;
      if (_payment == null) {
        _errorMessage = 'Odeme bilgisi bulunamadi.';
      }
      notifyListeners();
    } on PaymentActionException catch (error) {
      _hasLoaded = true;
      _errorMessage = error.message;
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  Future<FakePaymentResult?> submitFakePayment({
    required String cardHolderName,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final result = await _repository.processFakePayment(
        reservationId: reservationId,
        cardHolderName: cardHolderName,
        cardNumber: cardNumber,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvv: cvv,
      );
      _payment = result.payment;
      _errorMessage = null;
      notifyListeners();
      return result;
    } on PaymentActionException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }
}
