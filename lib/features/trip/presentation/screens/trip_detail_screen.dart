import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../reservation/data/repositories/reservation_repository.dart';
import '../../../reservation/presentation/helpers/reservation_presentation_helper.dart';
import '../../../reservation/presentation/models/reservation_route_arguments.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/trip_seat.dart';
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
        reservationRepository: context.read<ReservationRepository>(),
        tripId: arguments.tripId,
        role: arguments.role,
      )..load(),
      child: const _TripDetailView(),
    );
  }
}

class _TripDetailView extends StatefulWidget {
  const _TripDetailView();

  @override
  State<_TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends State<_TripDetailView> {
  String? _selectedSeatId;

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
    final viewModel = context.read<TripDetailViewModel>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _TripRejectDialog(),
    );

    if (!context.mounted || reason == null) {
      return;
    }

    try {
      final trip = await viewModel.rejectTrip(reason);
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

  Future<void> _createReservation(BuildContext context) async {
    final selectedSeatId = _selectedSeatId;
    if (selectedSeatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir koltuk seçin.')),
      );
      return;
    }

    try {
      final reservation = await context
          .read<TripDetailViewModel>()
          .createReservation(tripSeatId: selectedSeatId);
      if (!context.mounted || reservation == null) {
        return;
      }

      setState(() {
        _selectedSeatId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon talebi oluşturuldu.')),
      );
    } on TripReviewException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _isOwnReservationSeat(TripDetailViewModel viewModel, TripSeat seat) {
    return viewModel.currentUserReservation?.tripSeatId == seat.id;
  }

  Color _seatColor(
    BuildContext context,
    TripDetailViewModel viewModel,
    TripSeat seat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isOwnReservationSeat(viewModel, seat)) {
      return colorScheme.primaryContainer;
    }
    if (viewModel.isSeatBlocked(seat.id)) {
      return colorScheme.errorContainer;
    }
    return colorScheme.surfaceContainerHighest;
  }

  Widget _buildReservationCard(
    BuildContext context,
    TripDetailViewModel viewModel,
  ) {
    if (!viewModel.canCreateReservation) {
      return const SizedBox.shrink();
    }

    final reservation = viewModel.currentUserReservation;
    if (reservation != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Aktif Rezervasyonunuz',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Durum: ${ReservationPresentationHelper.statusLabel(reservation.status)}',
              ),
              if (reservation.seatNumber != null)
                Text('Koltuk: ${reservation.seatNumber}'),
              Text(
                'Talep Zamani: ${TripPresentationHelper.formatDateTime(reservation.requestedAt)}',
              ),
              if (reservation.status == ReservationStatus.approved)
                Text(
                  'Ödeme Son Tarihi: ${TripPresentationHelper.formatDateTime(reservation.paymentDeadlineAt)}',
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.reservationList,
                    arguments: const ReservationListArguments(
                      role: UserRole.normalUser,
                    ),
                  );
                },
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Rezervasyonlarima Git'),
              ),
            ],
          ),
        ),
      );
    }

    TripSeat? selectedSeat;
    if (_selectedSeatId != null) {
      for (final seat in viewModel.seats) {
        if (seat.id == _selectedSeatId) {
          selectedSeat = seat;
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rezervasyon Talebi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Müsait bir koltuk seçip rezervasyon talebi oluşturabilirsiniz.',
            ),
            const SizedBox(height: 12),
            Text(
              selectedSeat == null
                  ? 'Seçilen koltuk: Yok'
                  : 'Seçilen koltuk: ${selectedSeat.seatNumber}',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: viewModel.isBusy
                  ? null
                  : () => _createReservation(context),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Rezervasyon Talebi Gonder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatButton(
    BuildContext context,
    TripDetailViewModel viewModel,
    TripSeat seat,
  ) {
    final canPick =
        viewModel.canCreateReservation &&
        !viewModel.isSeatBlocked(seat.id) &&
        viewModel.currentUserReservation == null;

    final selected =
        _selectedSeatId == seat.id || _isOwnReservationSeat(viewModel, seat);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: canPick
          ? () {
              setState(() {
                _selectedSeatId = selected ? null : seat.id;
              });
            }
          : null,
      child: Container(
        height: 42,
        width: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : _seatColor(context, viewModel, seat),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          seat.seatNumber,
          style: TextStyle(
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
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
                      'Tür: ${TripPresentationHelper.transportLabel(trip.transportType)}',
                    ),
                    Text(
                      'Durum: ${TripPresentationHelper.statusLabel(trip.status)}',
                    ),
                    Text(
                      'Kalkış: ${TripPresentationHelper.formatDateTime(trip.departureAt)}',
                    ),
                    Text(
                      'Varış: ${TripPresentationHelper.formatDateTime(trip.arrivalAt)}',
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
            if (viewModel.canCreateReservation) ...[
              const SizedBox(height: 12),
              _buildReservationCard(context, viewModel),
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
                        'Admin İşlemleri',
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
                    _SeatLayoutView(
                      transportType: trip.transportType,
                      seats: viewModel.seats,
                      seatBuilder: (seat) {
                        return _buildSeatButton(context, viewModel, seat);
                      },
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

typedef _SeatBuilder = Widget Function(TripSeat seat);

class _SeatLayoutView extends StatelessWidget {
  const _SeatLayoutView({
    required this.transportType,
    required this.seats,
    required this.seatBuilder,
  });

  final TransportType transportType;
  final List<TripSeat> seats;
  final _SeatBuilder seatBuilder;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Text('Koltuk bilgisi bulunmuyor.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  transportType == TransportType.bus
                      ? Icons.directions_bus_outlined
                      : Icons.flight_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  transportType == TransportType.bus
                      ? '2+1 koltuk düzeni, son sıra dörtlü'
                      : '3+3 kabin düzeni',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (transportType == TransportType.bus)
              _buildBusLayout()
            else
              _buildFlightLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusLayout() {
    final rows = <Widget>[];
    final lastRowStart = seats.length > 4 ? seats.length - 4 : seats.length;
    final regularSeats = seats.take(lastRowStart).toList();
    final lastRowSeats = seats.skip(lastRowStart).toList();

    for (var index = 0; index < regularSeats.length; index += 3) {
      final rowSeats = regularSeats.skip(index).take(3).toList();
      rows.add(
        _buildSplitRow(
          leftSeats: rowSeats.take(2).toList(),
          rightSeats: rowSeats.skip(2).take(1).toList(),
        ),
      );
    }

    if (lastRowSeats.isNotEmpty) {
      rows.add(_buildFullRow(lastRowSeats));
    }

    return _buildRows(rows);
  }

  Widget _buildFlightLayout() {
    final rows = <Widget>[];
    for (var index = 0; index < seats.length; index += 6) {
      final rowSeats = seats.skip(index).take(6).toList();
      rows.add(
        _buildSplitRow(
          leftSeats: rowSeats.take(3).toList(),
          rightSeats: rowSeats.skip(3).take(3).toList(),
        ),
      );
    }
    return _buildRows(rows);
  }

  Widget _buildRows(List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSplitRow({
    required List<TripSeat> leftSeats,
    required List<TripSeat> rightSeats,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeatGroup(seats: leftSeats, seatBuilder: seatBuilder),
        const SizedBox(width: 34),
        _SeatGroup(seats: rightSeats, seatBuilder: seatBuilder),
      ],
    );
  }

  Widget _buildFullRow(List<TripSeat> rowSeats) {
    return _SeatGroup(seats: rowSeats, seatBuilder: seatBuilder);
  }
}

class _SeatGroup extends StatelessWidget {
  const _SeatGroup({required this.seats, required this.seatBuilder});

  final List<TripSeat> seats;
  final _SeatBuilder seatBuilder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < seats.length; index++) ...[
          seatBuilder(seats[index]),
          if (index != seats.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TripRejectDialog extends StatefulWidget {
  const _TripRejectDialog();

  @override
  State<_TripRejectDialog> createState() => _TripRejectDialogState();
}

class _TripRejectDialogState extends State<_TripRejectDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seferi Reddet'),
      content: TextField(
        controller: _reasonController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Red nedeni',
          hintText: 'Kisa bir aciklama yazin',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_reasonController.text.trim());
          },
          child: const Text('Reddet'),
        ),
      ],
    );
  }
}
