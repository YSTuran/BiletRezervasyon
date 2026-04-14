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

  Future<void> _openCompanyForm() async {
    await Navigator.of(context).pushNamed(AppRoutes.companyForm);
    if (!mounted) {
      return;
    }

    await _viewModel.load();
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
    final trips = viewModel.filteredTrips;
    final companyHintMessage = viewModel.tripCreationHintMessage;

    final filterBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tumu'),
            selected: viewModel.transportFilter == null,
            onSelected: (_) {
              viewModel.updateTransportFilter(null);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Otobus'),
            selected: viewModel.transportFilter == TransportType.bus,
            onSelected: (_) {
              viewModel.updateTransportFilter(TransportType.bus);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Ucak'),
            selected: viewModel.transportFilter == TransportType.flight,
            onSelected: (_) {
              viewModel.updateTransportFilter(TransportType.flight);
            },
          ),
        ],
      ),
    );

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
    } else if (trips.isEmpty) {
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
          itemCount: trips.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final trip = trips[index];
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
      body: Column(
        children: [
          filterBar,
          if (companyHintMessage != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(companyHintMessage),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _openCompanyForm,
                          icon: const Icon(Icons.apartment_outlined),
                          label: const Text('Firma Bilgileri'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}
