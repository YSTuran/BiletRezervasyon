import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../view_models/trip_list_view_model.dart';
import '../widgets/departure_countdown_chip.dart';

class CompanyTripCalendarScreen extends StatelessWidget {
  const CompanyTripCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TripListViewModel(
        repository: context.read<TripRepository>(),
        role: UserRole.companyOfficer,
      )..load(),
      child: const _CompanyTripCalendarView(),
    );
  }
}

class _CompanyTripCalendarView extends StatelessWidget {
  const _CompanyTripCalendarView();

  Map<DateTime, List<Trip>> _groupTripsByDay(List<Trip> trips) {
    final grouped = <DateTime, List<Trip>>{};
    for (final trip in trips) {
      final day = DateTime(
        trip.departureAt.year,
        trip.departureAt.month,
        trip.departureAt.day,
      );
      grouped.putIfAbsent(day, () => []).add(trip);
    }
    for (final dayTrips in grouped.values) {
      dayTrips.sort(
        (left, right) => left.departureAt.compareTo(right.departureAt),
      );
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripListViewModel>();
    final groupedTrips = _groupTripsByDay(viewModel.trips);

    Widget body;
    if (viewModel.isBusy && viewModel.trips.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.errorMessage != null && viewModel.trips.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: viewModel.load,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    } else if (groupedTrips.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Takvimde gösterilecek sefer bulunmuyor.'),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in groupedTrips.entries) ...[
              Text(
                TripPresentationHelper.formatDate(entry.key),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final trip in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CalendarTripCard(trip: trip),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sefer Takvimi')),
      body: body,
    );
  }
}

class _CalendarTripCard extends StatelessWidget {
  const _CalendarTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final style = TripPresentationHelper.visualStyle(trip);
    return Card(
      color: style.backgroundColor,
      child: ListTile(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.tripDetail,
            arguments: TripDetailArguments(
              role: UserRole.companyOfficer,
              tripId: trip.id,
            ),
          );
        },
        title: Text(
          '${trip.origin} -> ${trip.destination}',
          style: TextStyle(
            color: style.foregroundColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kod: ${trip.tripCode}'),
              Text(
                'Saat: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
              ),
              Text('Durum: ${TripPresentationHelper.statusLabel(trip.status)}'),
              const SizedBox(height: 6),
              DepartureCountdownChip(
                departureAt: trip.departureAt,
                compact: true,
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
