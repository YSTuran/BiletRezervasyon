import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../view_models/trip_list_view_model.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({required this.arguments, super.key});

  final TripListArguments arguments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TripListViewModel(
        repository: context.read<TripRepository>(),
        role: arguments.role,
      )..load(),
      child: const _TripListView(),
    );
  }
}

class _TripListView extends StatefulWidget {
  const _TripListView();

  @override
  State<_TripListView> createState() => _TripListViewState();
}

class _TripListViewState extends State<_TripListView> {
  TripListViewModel get _viewModel => context.read<TripListViewModel>();

  Future<void> _openTripDetails(String tripId) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.tripDetail,
      arguments: TripDetailArguments(role: _viewModel.role, tripId: tripId),
    );

    if (!mounted) {
      return;
    }

    await _viewModel.load();
  }

  Future<void> _openTripCreate() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.tripCreate,
      arguments: TripCreateArguments(role: _viewModel.role),
    );

    if (!mounted || result is! String) {
      return;
    }

    await _viewModel.load();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.tripDetail,
      arguments: TripDetailArguments(role: _viewModel.role, tripId: result),
    );
  }

  Color _statusColor(BuildContext context, Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (trip.status) {
      TripStatus.approved => colorScheme.primaryContainer,
      TripStatus.pendingApproval => colorScheme.secondaryContainer,
      TripStatus.rejected => colorScheme.errorContainer,
      TripStatus.cancelled => colorScheme.surfaceContainerHighest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripListViewModel>();

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
    } else if (viewModel.trips.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(viewModel.emptyMessage, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: viewModel.trips.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final trip = viewModel.trips[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text('${trip.origin} -> ${trip.destination}'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              TripPresentationHelper.statusLabel(trip.status),
                            ),
                            backgroundColor: _statusColor(context, trip),
                          ),
                          Chip(
                            label: Text(
                              TripPresentationHelper.transportLabel(
                                trip.transportType,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Kod: ${trip.tripCode}'),
                      Text(
                        'Kalkis: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                      ),
                      Text(
                        'Varis: ${TripPresentationHelper.formatDateTime(trip.arrivalAt)}',
                      ),
                      Text(
                        'Sure: ${TripPresentationHelper.formatDuration(trip)}',
                      ),
                      Text(
                        'Fiyat: ${TripPresentationHelper.formatPrice(trip.priceMinor)}',
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _openTripDetails(trip.id);
                },
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.title)),
      floatingActionButton: viewModel.canCreateTrip
          ? FloatingActionButton.extended(
              onPressed: _openTripCreate,
              icon: const Icon(Icons.add),
              label: const Text('Sefer Ekle'),
            )
          : null,
      body: body,
    );
  }
}
