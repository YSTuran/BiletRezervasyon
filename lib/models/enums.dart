enum UserRole {
  normalUser,
  companyOfficer,
  admin;

  String get value => switch (this) {
    UserRole.normalUser => 'normal_user',
    UserRole.companyOfficer => 'company_officer',
    UserRole.admin => 'admin',
  };

  static UserRole fromValue(String value) => switch (value) {
    'normal_user' => UserRole.normalUser,
    'company_officer' => UserRole.companyOfficer,
    'admin' => UserRole.admin,
    _ => throw ArgumentError('Unknown UserRole: $value'),
  };
}

enum ApprovalStatus {
  pending,
  approved,
  rejected;

  String get value => switch (this) {
    ApprovalStatus.pending => 'pending',
    ApprovalStatus.approved => 'approved',
    ApprovalStatus.rejected => 'rejected',
  };

  static ApprovalStatus fromValue(String value) => switch (value) {
    'pending' => ApprovalStatus.pending,
    'approved' => ApprovalStatus.approved,
    'rejected' => ApprovalStatus.rejected,
    _ => throw ArgumentError('Unknown ApprovalStatus: $value'),
  };
}

enum TransportType {
  bus,
  flight;

  String get value => switch (this) {
    TransportType.bus => 'bus',
    TransportType.flight => 'flight',
  };

  static TransportType fromValue(String value) => switch (value) {
    'bus' => TransportType.bus,
    'flight' => TransportType.flight,
    _ => throw ArgumentError('Unknown TransportType: $value'),
  };
}

enum TripStatus {
  pendingApproval,
  approved,
  rejected,
  cancelled;

  String get value => switch (this) {
    TripStatus.pendingApproval => 'pending_approval',
    TripStatus.approved => 'approved',
    TripStatus.rejected => 'rejected',
    TripStatus.cancelled => 'cancelled',
  };

  static TripStatus fromValue(String value) => switch (value) {
    'pending_approval' => TripStatus.pendingApproval,
    'approved' => TripStatus.approved,
    'rejected' => TripStatus.rejected,
    'cancelled' => TripStatus.cancelled,
    _ => throw ArgumentError('Unknown TripStatus: $value'),
  };
}

enum ReservationStatus {
  pendingApproval,
  approved,
  rejected,
  cancelledByUser,
  cancelledByCompany,
  expired,
  paid;

  String get value => switch (this) {
    ReservationStatus.pendingApproval => 'pending_approval',
    ReservationStatus.approved => 'approved',
    ReservationStatus.rejected => 'rejected',
    ReservationStatus.cancelledByUser => 'cancelled_by_user',
    ReservationStatus.cancelledByCompany => 'cancelled_by_company',
    ReservationStatus.expired => 'expired',
    ReservationStatus.paid => 'paid',
  };

  bool get blocksSeat => switch (this) {
    ReservationStatus.pendingApproval => true,
    ReservationStatus.approved => true,
    ReservationStatus.paid => true,
    ReservationStatus.rejected => false,
    ReservationStatus.cancelledByUser => false,
    ReservationStatus.cancelledByCompany => false,
    ReservationStatus.expired => false,
  };

  static ReservationStatus fromValue(String value) => switch (value) {
    'pending_approval' => ReservationStatus.pendingApproval,
    'approved' => ReservationStatus.approved,
    'rejected' => ReservationStatus.rejected,
    'cancelled_by_user' => ReservationStatus.cancelledByUser,
    'cancelled_by_company' => ReservationStatus.cancelledByCompany,
    'expired' => ReservationStatus.expired,
    'paid' => ReservationStatus.paid,
    _ => throw ArgumentError('Unknown ReservationStatus: $value'),
  };
}

enum RefundRequestStatus {
  pending,
  approved,
  rejected;

  String get value => switch (this) {
    RefundRequestStatus.pending => 'pending',
    RefundRequestStatus.approved => 'approved',
    RefundRequestStatus.rejected => 'rejected',
  };

  static RefundRequestStatus fromValue(String value) => switch (value) {
    'pending' => RefundRequestStatus.pending,
    'approved' => RefundRequestStatus.approved,
    'rejected' => RefundRequestStatus.rejected,
    _ => throw ArgumentError('Unknown RefundRequestStatus: $value'),
  };
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded;

  String get value => switch (this) {
    PaymentStatus.pending => 'pending',
    PaymentStatus.paid => 'paid',
    PaymentStatus.failed => 'failed',
    PaymentStatus.refunded => 'refunded',
  };

  static PaymentStatus fromValue(String value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'paid' => PaymentStatus.paid,
    'failed' => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    _ => throw ArgumentError('Unknown PaymentStatus: $value'),
  };
}
