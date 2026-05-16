import '../../../../models/enums.dart';

class AdminDashboard {
  const AdminDashboard({
    required this.summary,
    required this.pendingCompanies,
    required this.pendingTrips,
    required this.pendingReservations,
    required this.rejectionReasons,
  });

  final AdminDashboardSummary summary;
  final List<PendingCompanyPreview> pendingCompanies;
  final List<PendingTripPreview> pendingTrips;
  final List<PendingReservationPreview> pendingReservations;
  final List<DashboardRejectionReason> rejectionReasons;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      summary: AdminDashboardSummary.fromJson(_readMap(json['summary'])),
      pendingCompanies: _readMapList(
        json['pending_companies'],
      ).map(PendingCompanyPreview.fromJson).toList(),
      pendingTrips: _readMapList(
        json['pending_trips'],
      ).map(PendingTripPreview.fromJson).toList(),
      pendingReservations: _readMapList(
        json['pending_reservations'],
      ).map(PendingReservationPreview.fromJson).toList(),
      rejectionReasons: _readMapList(
        json['rejection_reasons'],
      ).map(DashboardRejectionReason.fromJson).take(3).toList(),
    );
  }
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.pendingCompanyCount,
    required this.pendingTripCount,
    required this.pendingReservationCount,
    required this.paidReservationCount,
    required this.paidPaymentCount,
    required this.totalSalesMinor,
  });

  final int pendingCompanyCount;
  final int pendingTripCount;
  final int pendingReservationCount;
  final int paidReservationCount;
  final int paidPaymentCount;
  final int totalSalesMinor;

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      pendingCompanyCount: _readInt(json['pending_company_count']),
      pendingTripCount: _readInt(json['pending_trip_count']),
      pendingReservationCount: _readInt(json['pending_reservation_count']),
      paidReservationCount: _readInt(json['paid_reservation_count']),
      paidPaymentCount: _readInt(json['paid_payment_count']),
      totalSalesMinor: _readInt(json['total_sales_minor']),
    );
  }
}

class PendingCompanyPreview {
  const PendingCompanyPreview({
    required this.id,
    required this.name,
    required this.transportType,
    required this.createdAt,
    required this.officerName,
    required this.officerEmail,
  });

  final String id;
  final String name;
  final TransportType transportType;
  final DateTime createdAt;
  final String officerName;
  final String officerEmail;

  factory PendingCompanyPreview.fromJson(Map<String, dynamic> json) {
    return PendingCompanyPreview(
      id: _readString(json['id']),
      name: _readString(json['name'], fallback: '-'),
      transportType: _readTransportType(json['transport_type']),
      createdAt: _readDate(json['created_at']),
      officerName: _readString(json['officer_name'], fallback: '-'),
      officerEmail: _readString(json['officer_email'], fallback: '-'),
    );
  }
}

class PendingTripPreview {
  const PendingTripPreview({
    required this.id,
    required this.tripCode,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.arrivalAt,
    required this.transportType,
    required this.companyName,
  });

  final String id;
  final String tripCode;
  final String origin;
  final String destination;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final TransportType transportType;
  final String companyName;

  factory PendingTripPreview.fromJson(Map<String, dynamic> json) {
    return PendingTripPreview(
      id: _readString(json['id']),
      tripCode: _readString(json['trip_code'], fallback: '-'),
      origin: _readString(json['origin'], fallback: '-'),
      destination: _readString(json['destination'], fallback: '-'),
      departureAt: _readDate(json['departure_at']),
      arrivalAt: _readDate(json['arrival_at']),
      transportType: _readTransportType(json['transport_type']),
      companyName: _readString(json['company_name'], fallback: '-'),
    );
  }
}

class PendingReservationPreview {
  const PendingReservationPreview({
    required this.id,
    required this.tripId,
    required this.tripCode,
    required this.origin,
    required this.destination,
    required this.seatNumber,
    required this.companyName,
    required this.requestedAt,
  });

  final String id;
  final String tripId;
  final String tripCode;
  final String origin;
  final String destination;
  final String seatNumber;
  final String companyName;
  final DateTime requestedAt;

  factory PendingReservationPreview.fromJson(Map<String, dynamic> json) {
    return PendingReservationPreview(
      id: _readString(json['id']),
      tripId: _readString(json['trip_id']),
      tripCode: _readString(json['trip_code'], fallback: '-'),
      origin: _readString(json['origin'], fallback: '-'),
      destination: _readString(json['destination'], fallback: '-'),
      seatNumber: _readString(json['seat_number'], fallback: '-'),
      companyName: _readString(json['company_name'], fallback: '-'),
      requestedAt: _readDate(json['requested_at']),
    );
  }
}

class DashboardRejectionReason {
  const DashboardRejectionReason({
    required this.category,
    required this.subject,
    required this.reason,
    required this.occurredAt,
  });

  final String category;
  final String subject;
  final String reason;
  final DateTime occurredAt;

  factory DashboardRejectionReason.fromJson(Map<String, dynamic> json) {
    return DashboardRejectionReason(
      category: _readString(json['category'], fallback: '-'),
      subject: _readString(json['subject'], fallback: '-'),
      reason: _readString(json['reason'], fallback: '-'),
      occurredAt: _readDate(json['occurred_at']),
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, data) => MapEntry('$key', data));
  }
  return const {};
}

Iterable<Map<String, dynamic>> _readMapList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_readMap).where((item) => item.isNotEmpty);
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return num.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}

DateTime _readDate(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return _readDateFromEpoch(value);
  }
  if (value is num) {
    return _readDateFromEpoch(value.toInt());
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round() +
            (nanoseconds is num ? nanoseconds ~/ 1000000 : 0),
        isUtc: true,
      );
    }
  }
  final text = value?.toString().trim() ?? '';
  return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime _readDateFromEpoch(int value) {
  final isMilliseconds = value.abs() > 9999999999;
  return DateTime.fromMillisecondsSinceEpoch(
    isMilliseconds ? value : value * 1000,
    isUtc: true,
  );
}

TransportType _readTransportType(dynamic value) {
  try {
    return TransportType.fromValue(_readString(value));
  } catch (_) {
    return TransportType.bus;
  }
}
