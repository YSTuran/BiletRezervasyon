import '../../../../models/enums.dart';

abstract final class CompanyPresentationHelper {
  static String transportLabel(TransportType transportType) {
    return switch (transportType) {
      TransportType.bus => 'Otobüs',
      TransportType.flight => 'Uçak',
    };
  }

  static String approvalLabel(ApprovalStatus status) {
    return switch (status) {
      ApprovalStatus.pending => 'Onay Bekliyor',
      ApprovalStatus.approved => 'Onaylandi',
      ApprovalStatus.rejected => 'Reddedildi',
    };
  }
}
