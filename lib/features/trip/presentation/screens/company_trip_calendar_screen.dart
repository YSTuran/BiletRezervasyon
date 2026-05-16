import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../view_models/trip_list_view_model.dart';

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

  Future<void> _openTripDetail(
    BuildContext context,
    TripListViewModel viewModel,
    Trip trip,
  ) async {
    final navigator = Navigator.of(context);

    await navigator.pushNamed(
      AppRoutes.tripDetail,
      arguments: TripDetailArguments(
        role: UserRole.companyOfficer,
        tripId: trip.id,
      ),
    );
    if (!context.mounted) {
      return;
    }

    await viewModel.load();
  }

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
    final calendarTrips = viewModel.trips
        .where((trip) => trip.status == TripStatus.approved)
        .toList();
    final groupedTrips = _groupTripsByDay(calendarTrips);

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
          child: Text('Takvimde gösterilecek onaylı sefer bulunmuyor.'),
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
                  child: _CalendarTripCard(
                    trip: trip,
                    onTap: () {
                      _openTripDetail(context, viewModel, trip);
                    },
                  ),
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

class _CalendarTripCard extends StatefulWidget {
  const _CalendarTripCard({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  State<_CalendarTripCard> createState() => _CalendarTripCardState();
}

class _CalendarTripCardState extends State<_CalendarTripCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final trip = widget.trip;
    final style = TripPresentationHelper.visualStyle(trip, now: now);

    return Card(
      color: style.backgroundColor,
      child: ListTile(
        onTap: widget.onTap,
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
              const SizedBox(height: 6),
              Chip(
                avatar: Icon(_statusIcon(trip, now), size: 18),
                label: Text(_statusLabel(trip, now)),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  IconData _statusIcon(Trip trip, DateTime now) {
    if (now.isBefore(trip.departureAt)) {
      return Icons.schedule_outlined;
    }
    if (now.isBefore(trip.arrivalAt)) {
      return Icons.local_shipping_outlined;
    }
    return Icons.check_circle_outline;
  }

  String _statusLabel(Trip trip, DateTime now) {
    if (now.isBefore(trip.departureAt)) {
      return 'Kalkışa ${_formatRemainingTime(trip.departureAt.difference(now))} kaldı';
    }
    if (now.isBefore(trip.arrivalAt)) {
      return 'Yolda';
    }
    return 'Vardı';
  }

  String _formatRemainingTime(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours;
    final remainingHours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      return '$days gün $remainingHours saat';
    }
    if (hours > 0) {
      return '$hours saat $minutes dakika';
    }
    if (minutes > 0) {
      return '$minutes dakika';
    }
    return 'çok az süre';
  }
}
