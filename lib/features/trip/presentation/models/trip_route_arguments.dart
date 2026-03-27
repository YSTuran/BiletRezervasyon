import '../../../../models/enums.dart';

class TripListArguments {
  const TripListArguments({required this.role});

  final UserRole role;
}

class TripDetailArguments {
  const TripDetailArguments({required this.role, required this.tripId});

  final UserRole role;
  final String tripId;
}

class TripCreateArguments {
  const TripCreateArguments({required this.role});

  final UserRole role;
}
