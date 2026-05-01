import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/models/payment.dart';
import '../helpers/payment_presentation_helper.dart';
import '../models/payment_route_arguments.dart';
import '../view_models/payment_list_view_model.dart';

class PaymentListScreen extends StatelessWidget {
  const PaymentListScreen({required this.arguments, super.key});

  final PaymentListArguments arguments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaymentListViewModel(
        repository: context.read<PaymentRepository>(),
        role: arguments.role,
      )..load(),
      child: const _PaymentListView(),
    );
  }
}

class _PaymentListView extends StatelessWidget {
  const _PaymentListView();

  Future<void> _openCheckout(BuildContext context, Payment payment) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.paymentCheckout,
      arguments: PaymentCheckoutArguments(reservationId: payment.reservationId),
    );

    if (!context.mounted || result != true) {
      return;
    }

    await context.read<PaymentListViewModel>().load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PaymentListViewModel>();

    Widget body;
    if (viewModel.isBusy && viewModel.payments.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.errorMessage != null && viewModel.payments.isEmpty) {
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
    } else if (viewModel.payments.isEmpty) {
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
          itemCount: viewModel.payments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final payment = viewModel.payments[index];
            final departureLabel = PaymentPresentationHelper.departureLabel(
              payment,
            );
            final transportLabel = PaymentPresentationHelper.transportLabel(
              payment,
            );

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PaymentPresentationHelper.routeLabel(payment),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            PaymentPresentationHelper.statusLabel(
                              payment.status,
                            ),
                          ),
                        ),
                        if (transportLabel != null)
                          Chip(label: Text(transportLabel)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (payment.tripCode != null)
                      Text('Sefer Kodu: ${payment.tripCode}'),
                    if (payment.seatNumber != null)
                      Text('Koltuk: ${payment.seatNumber}'),
                    if (departureLabel != null) Text('Kalkis: $departureLabel'),
                    Text(
                      'Tutar: ${PaymentPresentationHelper.formatPrice(payment.amountMinor)}',
                    ),
                    if (payment.paymentDeadlineAt != null)
                      Text(
                        'Odeme Son Tarihi: ${PaymentPresentationHelper.formatDateTime(payment.paymentDeadlineAt!)}',
                      ),
                    if (payment.paidAt != null)
                      Text(
                        'Odeme Zamani: ${PaymentPresentationHelper.formatDateTime(payment.paidAt!)}',
                      ),
                    if ((payment.companyName ?? '').trim().isNotEmpty)
                      Text('Firma: ${payment.companyName}'),
                    if (viewModel.canOpenCheckout(payment)) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _openCheckout(context, payment);
                              },
                        icon: const Icon(Icons.credit_card_outlined),
                        label: Text(
                          payment.status == PaymentStatus.failed
                              ? 'Tekrar Ode'
                              : 'Odeme Yap',
                        ),
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
