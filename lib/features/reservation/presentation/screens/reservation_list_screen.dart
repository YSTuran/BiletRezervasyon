import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../../payment/presentation/models/payment_route_arguments.dart';
import '../../data/repositories/reservation_repository.dart';
import '../../domain/models/reservation.dart';
import '../helpers/reservation_presentation_helper.dart';
import '../models/reservation_route_arguments.dart';
import '../view_models/reservation_list_view_model.dart';

class ReservationListScreen extends StatelessWidget {
  const ReservationListScreen({required this.arguments, super.key});

  final ReservationListArguments arguments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReservationListViewModel(
        repository: context.read<ReservationRepository>(),
        role: arguments.role,
      )..load(),
      child: const _ReservationListView(),
    );
  }
}

class _ReservationListView extends StatelessWidget {
  const _ReservationListView();

  Future<void> _openPayment(
    BuildContext context,
    Reservation reservation,
  ) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.paymentCheckout,
      arguments: PaymentCheckoutArguments(reservationId: reservation.id),
    );

    if (!context.mounted || result != true) {
      return;
    }

    await context.read<ReservationListViewModel>().load();
  }

  Future<void> _cancelReservation(
    BuildContext context,
    Reservation reservation,
  ) async {
    try {
      await context.read<ReservationListViewModel>().cancelReservation(
        reservation.id,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon iptal edildi.')),
      );
    } on ReservationActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _approveReservation(
    BuildContext context,
    Reservation reservation,
  ) async {
    try {
      await context.read<ReservationListViewModel>().approveReservation(
        reservation.id,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rezervasyon onaylandi.')));
    } on ReservationActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _rejectReservation(
    BuildContext context,
    Reservation reservation,
  ) async {
    final reasonController = TextEditingController();
    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rezervasyonu Reddet'),
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

    if (!context.mounted || rejectionReason == null) {
      return;
    }

    try {
      await context.read<ReservationListViewModel>().rejectReservation(
        reservationId: reservation.id,
        rejectionReason: rejectionReason,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rezervasyon reddedildi.')));
    } on ReservationActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ReservationListViewModel>();

    Widget body;
    if (viewModel.isBusy && viewModel.reservations.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.errorMessage != null &&
        viewModel.reservations.isEmpty) {
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
    } else if (viewModel.reservations.isEmpty) {
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
          itemCount: viewModel.reservations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final reservation = viewModel.reservations[index];
            final departureLabel = ReservationPresentationHelper.departureLabel(
              reservation,
            );
            final transportLabel = ReservationPresentationHelper.transportLabel(
              reservation,
            );
            final paymentDeadline =
                reservation.status == ReservationStatus.approved
                ? reservation.paymentDeadlineAt
                : null;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReservationPresentationHelper.routeLabel(reservation),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            ReservationPresentationHelper.statusLabel(
                              reservation.status,
                            ),
                          ),
                        ),
                        if (transportLabel != null)
                          Chip(label: Text(transportLabel)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (reservation.tripCode != null)
                      Text('Sefer Kodu: ${reservation.tripCode}'),
                    if (reservation.seatNumber != null)
                      Text('Koltuk: ${reservation.seatNumber}'),
                    if (departureLabel != null) Text('Kalkış: $departureLabel'),
                    Text(
                      'Talep Zamani: ${ReservationPresentationHelper.formatDateTime(reservation.requestedAt)}',
                    ),
                    if (paymentDeadline != null)
                      Text(
                        'Ödeme Son Tarihi: ${ReservationPresentationHelper.formatDateTime(paymentDeadline)}',
                      ),
                    if ((reservation.companyName ?? '').trim().isNotEmpty)
                      Text('Firma: ${reservation.companyName}'),
                    if ((reservation.rejectionReason ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Red nedeni: ${reservation.rejectionReason}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (viewModel.canCancel(reservation) ||
                        viewModel.canReview(reservation) ||
                        viewModel.canPay(reservation)) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (viewModel.canCancel(reservation))
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: viewModel.isBusy
                                    ? null
                                    : () {
                                        _cancelReservation(
                                          context,
                                          reservation,
                                        );
                                      },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('İptal Et'),
                              ),
                            ),
                          if (viewModel.canPay(reservation)) ...[
                            if (viewModel.canCancel(reservation))
                              const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: viewModel.isBusy
                                    ? null
                                    : () {
                                        _openPayment(context, reservation);
                                      },
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Ödeme Yap'),
                              ),
                            ),
                          ],
                          if (viewModel.canReview(reservation)) ...[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: viewModel.isBusy
                                    ? null
                                    : () {
                                        _approveReservation(
                                          context,
                                          reservation,
                                        );
                                      },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Onayla'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: viewModel.isBusy
                                    ? null
                                    : () {
                                        _rejectReservation(
                                          context,
                                          reservation,
                                        );
                                      },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Reddet'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.title)),
      body: body,
    );
  }
}
