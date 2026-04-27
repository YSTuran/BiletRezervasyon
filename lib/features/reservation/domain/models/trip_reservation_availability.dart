import 'reservation.dart';

class TripReservationAvailability {
  const TripReservationAvailability({
    required this.blockedSeatIds,
    required this.currentUserActiveReservation,
  });

  final Set<String> blockedSeatIds;
  final Reservation? currentUserActiveReservation;
}
