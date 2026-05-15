import '../../../../models/enums.dart';
import '../../../trip/presentation/helpers/trip_presentation_helper.dart';
import '../../domain/models/payment.dart';

abstract final class PaymentPresentationHelper {
  static String statusLabel(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.pending => 'Bekliyor',
      PaymentStatus.paid => 'Ödendi',
      PaymentStatus.failed => 'Başarısız',
      PaymentStatus.refunded => 'İade Edildi',
    };
  }

  static String refundRequestStatusLabel(RefundRequestStatus status) {
    return switch (status) {
      RefundRequestStatus.pending => 'Firma Onayı Bekliyor',
      RefundRequestStatus.approved => 'Onaylandı',
      RefundRequestStatus.rejected => 'Reddedildi',
    };
  }

  static String routeLabel(Payment payment) {
    final origin = payment.tripOrigin ?? '-';
    final destination = payment.tripDestination ?? '-';
    return '$origin -> $destination';
  }

  static String? departureLabel(Payment payment) {
    final departureAt = payment.tripDepartureAt;
    if (departureAt == null) {
      return null;
    }
    return TripPresentationHelper.formatDateTime(departureAt);
  }

  static String formatPrice(int priceMinor) {
    return TripPresentationHelper.formatPrice(priceMinor);
  }

  static String formatDateTime(DateTime value) {
    return TripPresentationHelper.formatDateTime(value);
  }

  static String? transportLabel(Payment payment) {
    final transportType = payment.tripTransportType;
    if (transportType == null) {
      return null;
    }
    return switch (transportType) {
      TransportType.bus => 'Otobüs',
      TransportType.flight => 'Uçak',
    };
  }

  static String? refundSummaryLabel(Payment payment) {
    final summary = payment.refundSummary?.trim();
    if (summary == null || summary.isEmpty) {
      return null;
    }
    return summary;
  }
}
