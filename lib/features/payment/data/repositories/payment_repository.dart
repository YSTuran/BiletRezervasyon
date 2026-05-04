import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../domain/models/payment.dart';

class PaymentRepository {
  Future<List<Payment>> fetchPayments() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'listPayments',
      );
      return _parsePayments(response['payments']);
    } on FirebaseFunctionsException catch (error) {
      throw PaymentActionException(_mapPaymentError(error.code, error.message));
    }
  }

  Future<Payment?> fetchReservationPayment({
    required String reservationId,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getReservationPayment',
        data: {'reservationId': reservationId},
      );
      return _parsePayment(response['payment']);
    } on FirebaseFunctionsException catch (error) {
      throw PaymentActionException(_mapPaymentError(error.code, error.message));
    }
  }

  Future<FakePaymentResult> processFakePayment({
    required String reservationId,
    required String cardHolderName,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'processFakePayment',
        data: {
          'reservationId': reservationId,
          'cardHolderName': cardHolderName.trim(),
          'cardNumber': cardNumber.trim(),
          'expiryMonth': expiryMonth.trim(),
          'expiryYear': expiryYear.trim(),
          'cvv': cvv.trim(),
        },
      );

      final payment = _parsePayment(response['payment']);
      if (payment == null) {
        throw const PaymentActionException('Odeme sonucu alinamadi.');
      }

      return FakePaymentResult(
        payment: payment,
        succeeded: response['succeeded'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      throw PaymentActionException(_mapPaymentError(error.code, error.message));
    }
  }

  Future<RefundPaymentResult> requestRefund({
    required String reservationId,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'requestRefund',
        data: {'reservationId': reservationId},
      );

      final payment = _parsePayment(response['payment']);
      if (payment == null) {
        throw const PaymentActionException('Iade sonucu alinamadi.');
      }

      return RefundPaymentResult(
        payment: payment,
        refundAmountMinor: response['refundAmountMinor'] as int? ?? 0,
        refundSummary:
            (response['refundSummary'] as String?)?.trim() ??
            'Iade islemi tamamlandi.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw PaymentActionException(_mapPaymentError(error.code, error.message));
    }
  }

  Payment? _parsePayment(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return Payment.fromJson(_toMap(value));
  }

  List<Payment> _parsePayments(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((payment) => Payment.fromJson(_toMap(payment)))
        .toList();
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) => MapEntry('$key', data));
  }

  String _mapPaymentError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Odeme kaydi bulunamadi.';
      case 'permission-denied':
        return 'Bu islem icin yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulasilamadi. Lutfen daha sonra tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Odeme islemi tamamlanamadi.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Odeme islemi tamamlanamadi.';
    }
  }
}

class FakePaymentResult {
  const FakePaymentResult({required this.payment, required this.succeeded});

  final Payment payment;
  final bool succeeded;
}

class RefundPaymentResult {
  const RefundPaymentResult({
    required this.payment,
    required this.refundAmountMinor,
    required this.refundSummary,
  });

  final Payment payment;
  final int refundAmountMinor;
  final String refundSummary;
}

class PaymentActionException implements Exception {
  const PaymentActionException(this.message);

  final String message;
}
