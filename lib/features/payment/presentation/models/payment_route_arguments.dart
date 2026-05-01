import '../../../../models/enums.dart';

class PaymentListArguments {
  const PaymentListArguments({required this.role});

  final UserRole role;
}

class PaymentCheckoutArguments {
  const PaymentCheckoutArguments({required this.reservationId});

  final String reservationId;
}
