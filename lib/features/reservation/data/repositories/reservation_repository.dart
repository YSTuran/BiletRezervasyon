import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../domain/models/reservation.dart';
import '../../domain/models/trip_reservation_availability.dart';

class ReservationRepository {
  Future<List<Reservation>> fetchReservations() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'listReservations',
      );
      return _parseReservations(response['reservations']);
    } on FirebaseFunctionsException catch (error) {
      throw ReservationActionException(
        _mapReservationError(error.code, error.message),
      );
    }
  }

  Future<TripReservationAvailability> fetchTripReservationAvailability({
    required String tripId,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getTripReservationAvailability',
        data: {'tripId': tripId},
      );

      final blockedSeatIds =
          (response['blockedSeatIds'] as List<dynamic>? ?? [])
              .map((value) => '$value')
              .toSet();

      return TripReservationAvailability(
        blockedSeatIds: blockedSeatIds,
        currentUserActiveReservation: _parseReservation(
          response['currentUserReservation'],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      throw ReservationActionException(
        _mapReservationError(error.code, error.message),
      );
    }
  }

  Future<Reservation> createReservation({
    required String tripId,
    required String tripSeatId,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'createReservation',
        data: {'tripId': tripId, 'tripSeatId': tripSeatId},
      );

      final reservation = _parseReservation(response['reservation']);
      if (reservation == null) {
        throw const ReservationActionException('Rezervasyon oluşturulamadı.');
      }
      return reservation;
    } on FirebaseFunctionsException catch (error) {
      throw ReservationActionException(
        _mapReservationError(error.code, error.message),
      );
    }
  }

  Future<Reservation?> cancelReservation({
    required String reservationId,
  }) async {
    return _updateReservation(
      functionName: 'cancelReservation',
      data: {'reservationId': reservationId},
    );
  }

  Future<Reservation?> approveReservation({
    required String reservationId,
  }) async {
    return _updateReservation(
      functionName: 'reviewReservation',
      data: {'reservationId': reservationId, 'status': 'approved'},
    );
  }

  Future<Reservation?> rejectReservation({
    required String reservationId,
    required String rejectionReason,
  }) async {
    final trimmedReason = rejectionReason.trim();
    if (trimmedReason.isEmpty) {
      throw const ReservationActionException('Red nedeni zorunludur.');
    }

    return _updateReservation(
      functionName: 'reviewReservation',
      data: {
        'reservationId': reservationId,
        'status': 'rejected',
        'rejectionReason': trimmedReason,
      },
    );
  }

  Future<Reservation?> _updateReservation({
    required String functionName,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: functionName,
        data: data,
      );
      return _parseReservation(response['reservation']);
    } on FirebaseFunctionsException catch (error) {
      throw ReservationActionException(
        _mapReservationError(error.code, error.message),
      );
    }
  }

  Reservation? _parseReservation(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return Reservation.fromJson(_toMap(value));
  }

  List<Reservation> _parseReservations(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((reservation) => Reservation.fromJson(_toMap(reservation)))
        .toList();
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) => MapEntry('$key', data));
  }

  String _mapReservationError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Rezervasyon bulunamadı.';
      case 'already-exists':
        return trimmedMessage.isNotEmpty
            ? trimmedMessage
            : 'Bu koltuk için aktif rezervasyon zaten bulunuyor.';
      case 'permission-denied':
        return 'Bu işlem için yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Rezervasyon işlemi tamamlanamadı.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Rezervasyon işlemi tamamlanamadı.';
    }
  }
}

class ReservationActionException implements Exception {
  const ReservationActionException(this.message);

  final String message;
}
