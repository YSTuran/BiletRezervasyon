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

  Future<void> _createReservation(BuildContext context) async {
    final selectedSeatId = _selectedSeatId;
    if (selectedSeatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen once bir koltuk secin.')),
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
        const SnackBar(content: Text('Rezervasyon talebi olusturuldu.')),
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
                  'Odeme Son Tarihi: ${TripPresentationHelper.formatDateTime(reservation.paymentDeadlineAt)}',
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
              'Musaid bir koltuk secip rezervasyon talebi olusturabilirsiniz.',
            ),
            const SizedBox(height: 12),
            Text(
              selectedSeat == null
                  ? 'Secilen koltuk: Yok'
                  : 'Secilen koltuk: ${selectedSeat.seatNumber}',
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

  Widget _buildSeatChip(
    BuildContext context,
    TripDetailViewModel viewModel,
    TripSeat seat,
  ) {
    final canPick =
        viewModel.canCreateReservation &&
        !viewModel.isSeatBlocked(seat.id) &&
        viewModel.currentUserReservation == null;

    return ChoiceChip(
      label: Text(seat.seatNumber),
      selected:
          _selectedSeatId == seat.id || _isOwnReservationSeat(viewModel, seat),
      onSelected: canPick
          ? (selected) {
              setState(() {
                _selectedSeatId = selected ? seat.id : null;
              });
            }
          : null,
      backgroundColor: _seatColor(context, viewModel, seat),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
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
                          .map(
                            (seat) => _buildSeatChip(context, viewModel, seat),
                          )
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
