import '../../../../models/enums.dart';
import '../../../trip/presentation/helpers/trip_presentation_helper.dart';
import '../../domain/models/reservation.dart';

abstract final class ReservationPresentationHelper {
  static String formatDateTime(DateTime value) {
    return TripPresentationHelper.formatDateTime(value);
  }

  static String statusLabel(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pendingApproval => 'Onay Bekliyor',
      ReservationStatus.approved => 'Onaylandi',
      ReservationStatus.rejected => 'Reddedildi',
      ReservationStatus.cancelledByUser => 'Kullanıcı İptal Etti',
      ReservationStatus.expired => 'Suresi Doldu',
      ReservationStatus.paid => 'Odendi',
    };
  }

  static String routeLabel(Reservation reservation) {
    final origin = reservation.tripOrigin ?? '-';
    final destination = reservation.tripDestination ?? '-';
    return '$origin -> $destination';
  }

  static String? departureLabel(Reservation reservation) {
    final departureAt = reservation.tripDepartureAt;
    if (departureAt == null) {
      return null;
    }
    return formatDateTime(departureAt);
  }

  static String? transportLabel(Reservation reservation) {
    final transportType = reservation.tripTransportType;
    if (transportType == null) {
      return null;
    }
    return switch (transportType) {
      TransportType.bus => 'Otobüs',
      TransportType.flight => 'Uçak',
    };
  }
}
