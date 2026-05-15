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
    UserRole.normalUser => 'Ödemelerim',
    UserRole.companyOfficer => 'Ödeme Kayıtları',
    UserRole.admin => 'Tüm Ödemeler',
  };

  String get emptyMessage => switch (role) {
    UserRole.normalUser => 'Henüz bir ödeme kaydınız bulunmuyor.',
    UserRole.companyOfficer => 'Şirket seferleri için ödeme kaydı bulunmuyor.',
    UserRole.admin => 'Gösterilecek ödeme kaydı bulunmuyor.',
  };

  bool canOpenCheckout(Payment payment) {
    return role == UserRole.normalUser &&
        payment.reservationStatus == ReservationStatus.approved &&
        (payment.status == PaymentStatus.pending ||
            payment.status == PaymentStatus.failed);
  }

  bool canRequestRefund(Payment payment) {
    return role == UserRole.normalUser && payment.canRequestRefund;
  }

  bool canReviewRefund(Payment payment) {
    return role == UserRole.companyOfficer &&
        payment.refundRequestId != null &&
        payment.refundRequestStatus == RefundRequestStatus.pending;
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

  Future<RefundPaymentResult?> requestRefund(String reservationId) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final result = await _repository.requestRefund(
        reservationId: reservationId,
      );
      _replacePayment(result.payment);
      _errorMessage = null;
      notifyListeners();
      return result;
    } on PaymentActionException {
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  Future<Payment?> approveRefundRequest(String refundRequestId) async {
    return _reviewRefundRequest(
      refundRequestId: refundRequestId,
      status: RefundRequestStatus.approved,
    );
  }

  Future<Payment?> rejectRefundRequest({
    required String refundRequestId,
    required String rejectionReason,
  }) async {
    final trimmedReason = rejectionReason.trim();
    if (trimmedReason.isEmpty) {
      throw const PaymentActionException('Red nedeni zorunludur.');
    }
    return _reviewRefundRequest(
      refundRequestId: refundRequestId,
      status: RefundRequestStatus.rejected,
      rejectionReason: trimmedReason,
    );
  }

  Future<Payment?> _reviewRefundRequest({
    required String refundRequestId,
    required RefundRequestStatus status,
    String? rejectionReason,
  }) async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      final payment = await _repository.reviewRefundRequest(
        refundRequestId: refundRequestId,
        status: status,
        rejectionReason: rejectionReason,
      );
      if (payment != null) {
        _replacePayment(payment);
        _errorMessage = null;
        notifyListeners();
      }
      return payment;
    } on PaymentActionException {
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  void _replacePayment(Payment updatedPayment) {
    final index = _payments.indexWhere(
      (payment) => payment.id == updatedPayment.id,
    );
    if (index == -1) {
      _payments = [updatedPayment, ..._payments];
      return;
    }

    final nextPayments = [..._payments];
    nextPayments[index] = updatedPayment;
    _payments = nextPayments;
  }
}
