import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../models/trip_sort_option.dart';
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
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  TripListViewModel get _viewModel => context.read<TripListViewModel>();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

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

  Future<void> _pickDepartureDate() async {
    final viewModel = _viewModel;
    final now = DateTime.now();
    final initialDate = viewModel.departureDateFilter ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (!mounted) {
      return;
    }

    viewModel.updateDepartureDateFilter(selectedDate);
  }

  void _clearFilters() {
    _originController.clear();
    _destinationController.clear();
    _viewModel.clearFilters();
  }

  String _formatDate(DateTime value) {
    final day = '${value.day}'.padLeft(2, '0');
    final month = '${value.month}'.padLeft(2, '0');
    final year = value.year;
    return '$day.$month.$year';
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

    final filterBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sefer Ara', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _originController,
                onChanged: viewModel.updateOriginQuery,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nereden',
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _destinationController,
                onChanged: viewModel.updateDestinationQuery,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Nereye',
                  prefixIcon: Icon(Icons.flight_land_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TripSortOption>(
                key: ValueKey(viewModel.sortOption),
                initialValue: viewModel.sortOption,
                decoration: const InputDecoration(
                  labelText: 'Siralama',
                  prefixIcon: Icon(Icons.sort_outlined),
                ),
                items: TripSortOption.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    viewModel.updateSortOption(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tumu'),
                    selected: viewModel.transportFilter == null,
                    onSelected: (_) {
                      viewModel.updateTransportFilter(null);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Otobus'),
                    selected: viewModel.transportFilter == TransportType.bus,
                    onSelected: (_) {
                      viewModel.updateTransportFilter(TransportType.bus);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Ucak'),
                    selected: viewModel.transportFilter == TransportType.flight,
                    onSelected: (_) {
                      viewModel.updateTransportFilter(TransportType.flight);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDepartureDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      viewModel.departureDateFilter == null
                          ? 'Tarih Sec'
                          : _formatDate(viewModel.departureDateFilter!),
                    ),
                  ),
                  if (viewModel.departureDateFilter != null)
                    TextButton(
                      onPressed: () {
                        viewModel.updateDepartureDateFilter(null);
                      },
                      child: const Text('Tarihi Temizle'),
                    ),
                  if (viewModel.hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Filtreleri Temizle'),
                    ),
                ],
              ),
            ],
          ),
        ),
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
