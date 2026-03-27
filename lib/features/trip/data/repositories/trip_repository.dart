import '../../domain/models/trip.dart';
import '../../domain/models/trip_seat.dart';

class TripRepository {
  Future<List<Trip>> fetchTrips() async {
    return const [];
  }

  Future<List<TripSeat>> fetchTripSeats({required String tripId}) async {
    return const [];
  }
}
