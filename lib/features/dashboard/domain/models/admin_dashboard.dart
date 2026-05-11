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
      summary: AdminDashboardSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      pendingCompanies:
          (json['pending_companies'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PendingCompanyPreview.fromJson)
              .toList(),
      pendingTrips: (json['pending_trips'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PendingTripPreview.fromJson)
          .toList(),
      pendingReservations:
          (json['pending_reservations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PendingReservationPreview.fromJson)
              .toList(),
      rejectionReasons:
          (json['rejection_reasons'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(DashboardRejectionReason.fromJson)
              .toList(),
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
      pendingCompanyCount: json['pending_company_count'] as int? ?? 0,
      pendingTripCount: json['pending_trip_count'] as int? ?? 0,
      pendingReservationCount: json['pending_reservation_count'] as int? ?? 0,
      paidReservationCount: json['paid_reservation_count'] as int? ?? 0,
      paidPaymentCount: json['paid_payment_count'] as int? ?? 0,
      totalSalesMinor: json['total_sales_minor'] as int? ?? 0,
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
      id: json['id'] as String,
      name: json['name'] as String,
      transportType: TransportType.fromValue(json['transport_type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      officerName: json['officer_name'] as String? ?? '-',
      officerEmail: json['officer_email'] as String? ?? '-',
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
      id: json['id'] as String,
      tripCode: json['trip_code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String),
      arrivalAt: DateTime.parse(json['arrival_at'] as String),
      transportType: TransportType.fromValue(json['transport_type'] as String),
      companyName: json['company_name'] as String? ?? '-',
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
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      tripCode: json['trip_code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      seatNumber: json['seat_number'] as String,
      companyName: json['company_name'] as String? ?? '-',
      requestedAt: DateTime.parse(json['requested_at'] as String),
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
      category: json['category'] as String? ?? '-',
      subject: json['subject'] as String? ?? '-',
      reason: json['reason'] as String? ?? '-',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }
}
