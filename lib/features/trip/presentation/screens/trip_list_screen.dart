import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../models/trip_sort_option.dart';
import '../view_models/trip_list_view_model.dart';
import '../widgets/departure_countdown_chip.dart';

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripListViewModel>();
    final trips = viewModel.pagedTrips;
    final companyHintMessage = viewModel.tripCreationHintMessage;

    final filterBar = viewModel.showsFilters
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sefer Ara',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                        labelText: 'Sıralama',
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
                          label: const Text('Tümü'),
                          selected: viewModel.transportFilter == null,
                          onSelected: (_) {
                            viewModel.updateTransportFilter(null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Otobüs'),
                          selected:
                              viewModel.transportFilter == TransportType.bus,
                          onSelected: (_) {
                            viewModel.updateTransportFilter(TransportType.bus);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Uçak'),
                          selected:
                              viewModel.transportFilter == TransportType.flight,
                          onSelected: (_) {
                            viewModel.updateTransportFilter(
                              TransportType.flight,
                            );
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
                                ? 'Tarih Seç'
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
          )
        : null;

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
            final visualStyle = TripPresentationHelper.visualStyle(trip);
            return Card(
              color: visualStyle.backgroundColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: visualStyle.borderColor, width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  _openTripDetails(trip.id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: visualStyle.borderColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              visualStyle.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              TripPresentationHelper.transportLabel(
                                trip.transportType,
                              ),
                              style: TextStyle(
                                color: visualStyle.foregroundColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${trip.origin} -> ${trip.destination}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: visualStyle.foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kod: ${trip.tripCode}',
                        style: TextStyle(color: visualStyle.foregroundColor),
                      ),
                      Text(
                        'Kalkış: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                        style: TextStyle(color: visualStyle.foregroundColor),
                      ),
                      if (viewModel.role == UserRole.normalUser) ...[
                        const SizedBox(height: 8),
                        DepartureCountdownChip(
                          departureAt: trip.departureAt,
                          compact: true,
                        ),
                      ],
                      Text(
                        'Varış: ${TripPresentationHelper.formatDateTime(trip.arrivalAt)}',
                        style: TextStyle(color: visualStyle.foregroundColor),
                      ),
                      Text(
                        'Süre: ${TripPresentationHelper.formatDuration(trip)}',
                        style: TextStyle(color: visualStyle.foregroundColor),
                      ),
                      Text(
                        'Fiyat: ${TripPresentationHelper.formatPrice(trip.priceMinor)}',
                        style: TextStyle(
                          color: visualStyle.foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((trip.rejectionReason ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Not: ${trip.rejectionReason}',
                          style: TextStyle(
                            color: visualStyle.foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.title)),
      bottomNavigationBar: _TripPaginationBar(viewModel: viewModel),
      floatingActionButton: viewModel.canCreateTrip
          ? FloatingActionButton.extended(
              onPressed: _openTripCreate,
              icon: const Icon(Icons.add),
              label: const Text('Sefer Ekle'),
            )
          : null,
      body: Column(
        children: [
          ?filterBar,
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

class _TripPaginationBar extends StatelessWidget {
  const _TripPaginationBar({required this.viewModel});

  final TripListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BottomAppBar(
      color: colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Önceki sayfa',
                onPressed: viewModel.canGoPrevious
                    ? viewModel.goToPreviousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sayfa ${viewModel.currentPageNumber} / ${viewModel.totalPages}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Her sayfada en fazla ${TripListViewModel.pageSize} sefer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sonraki sayfa',
                onPressed: viewModel.canGoNext ? viewModel.goToNextPage : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
