import '../../../../models/enums.dart';
import 'trip_sort_option.dart';

class TripSearchFilter {
  const TripSearchFilter({
    this.transportType,
    this.originQuery = '',
    this.destinationQuery = '',
    this.departureDate,
    this.sortOption = TripSortOption.departureAscending,
  });

  final TransportType? transportType;
  final String originQuery;
  final String destinationQuery;
  final DateTime? departureDate;
  final TripSortOption sortOption;

  bool get hasActiveFilters =>
      transportType != null ||
      originQuery.trim().isNotEmpty ||
      destinationQuery.trim().isNotEmpty ||
      departureDate != null ||
      sortOption != TripSortOption.departureAscending;

  TripSearchFilter copyWith({
    Object? transportType = _unset,
    String? originQuery,
    String? destinationQuery,
    Object? departureDate = _unset,
    TripSortOption? sortOption,
  }) {
    return TripSearchFilter(
      transportType: identical(transportType, _unset)
          ? this.transportType
          : transportType as TransportType?,
      originQuery: originQuery ?? this.originQuery,
      destinationQuery: destinationQuery ?? this.destinationQuery,
      departureDate: identical(departureDate, _unset)
          ? this.departureDate
          : departureDate as DateTime?,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

const Object _unset = Object();
