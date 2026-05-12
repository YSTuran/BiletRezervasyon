import '../../../../models/enums.dart';

abstract final class SeatCapacityPolicy {
  static List<int> optionsFor(TransportType transportType) {
    return switch (transportType) {
      TransportType.bus => const [31, 34, 37, 40, 43],
      TransportType.flight => const [150, 160, 170, 180, 190],
    };
  }

  static int defaultFor(TransportType transportType) {
    return optionsFor(transportType).first;
  }

  static String layoutLabelFor(TransportType transportType) {
    return switch (transportType) {
      TransportType.bus => '2+1, son sira dortlu',
      TransportType.flight => '3+3 kabin duzeni',
    };
  }

  static bool isAllowed({
    required TransportType transportType,
    required int seatCapacity,
  }) {
    return optionsFor(transportType).contains(seatCapacity);
  }
}
