import '../../../../models/enums.dart';
import '../../domain/models/trip.dart';

abstract final class TripPresentationHelper {
  static String transportLabel(TransportType transportType) {
    return switch (transportType) {
      TransportType.bus => 'Otobus',
      TransportType.flight => 'Ucak',
    };
  }

  static String statusLabel(TripStatus status) {
    return switch (status) {
      TripStatus.pendingApproval => 'Onay Bekliyor',
      TripStatus.approved => 'Onaylandi',
      TripStatus.rejected => 'Reddedildi',
      TripStatus.cancelled => 'Iptal Edildi',
    };
  }

  static String formatPrice(int priceMinor) {
    final price = (priceMinor / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '$price TL';
  }

  static String formatDateTime(DateTime value) {
    final day = '${value.day}'.padLeft(2, '0');
    final month = '${value.month}'.padLeft(2, '0');
    final year = value.year;
    final hour = '${value.hour}'.padLeft(2, '0');
    final minute = '${value.minute}'.padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  static String formatDuration(Trip trip) {
    final duration = trip.arrivalAt.difference(trip.departureAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}sa ${minutes}dk';
  }
}
