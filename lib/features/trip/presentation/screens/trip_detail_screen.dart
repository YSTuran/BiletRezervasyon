import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/trip_repository.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../view_models/trip_detail_view_model.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({required this.arguments, super.key});

  final TripDetailArguments arguments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TripDetailViewModel(
        repository: context.read<TripRepository>(),
        tripId: arguments.tripId,
        role: arguments.role,
      )..load(),
      child: const _TripDetailView(),
    );
  }
}

class _TripDetailView extends StatelessWidget {
  const _TripDetailView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripDetailViewModel>();
    final trip = viewModel.trip;

    if (viewModel.isBusy && trip == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (viewModel.errorMessage != null && trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sefer Detayi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(viewModel.errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Sefer bulunamadi.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(trip.tripCode)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.origin} -> ${trip.destination}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tur: ${TripPresentationHelper.transportLabel(trip.transportType)}',
                    ),
                    Text(
                      'Durum: ${TripPresentationHelper.statusLabel(trip.status)}',
                    ),
                    Text(
                      'Kalkis: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                    ),
                    Text(
                      'Varis: ${TripPresentationHelper.formatDateTime(trip.arrivalAt)}',
                    ),
                    Text(
                      'Sure: ${TripPresentationHelper.formatDuration(trip)}',
                    ),
                    Text('Kapasite: ${trip.seatCapacity} koltuk'),
                    Text(
                      'Fiyat: ${TripPresentationHelper.formatPrice(trip.priceMinor)}',
                    ),
                    if ((trip.rejectionReason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Red nedeni: ${trip.rejectionReason}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (viewModel.showManagementHint) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Bu ekranda seferin durumunu, kapasitesini ve olasi operasyon bilgilerini izleyebilirsiniz.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koltuklar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: viewModel.seats
                          .map((seat) => Chip(label: Text(seat.seatNumber)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
