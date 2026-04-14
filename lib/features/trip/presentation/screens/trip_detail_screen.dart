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

  Future<void> _approveTrip(BuildContext context) async {
    final viewModel = context.read<TripDetailViewModel>();

    try {
      final trip = await viewModel.approveTrip();
      if (!context.mounted || trip == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sefer onaylandi.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sefer onaylanamadi.')));
    }
  }

  Future<void> _rejectTrip(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Seferi Reddet'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Red nedeni',
              hintText: 'Kisa bir aciklama yazin',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();

    if (!context.mounted || reason == null) {
      return;
    }

    try {
      final trip = await context.read<TripDetailViewModel>().rejectTrip(reason);
      if (!context.mounted || trip == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sefer reddedildi.')));
    } on TripReviewException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sefer reddedilemedi.')));
    }
  }

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
            if (viewModel.canReviewTrip) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Admin Islemleri',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _approveTrip(context);
                              },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Seferi Onayla'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _rejectTrip(context);
                              },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Seferi Reddet'),
                      ),
                    ],
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
