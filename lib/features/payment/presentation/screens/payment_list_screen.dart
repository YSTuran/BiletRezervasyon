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

  Future<bool> _confirmRefund(BuildContext context, Payment payment) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final refundAmountMinor = payment.refundAmountMinor;
            final refundSummary = PaymentPresentationHelper.refundSummaryLabel(
              payment,
            );

            return AlertDialog(
              title: const Text('İade Talebi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(PaymentPresentationHelper.routeLabel(payment)),
                  if (refundSummary != null) ...[
                    const SizedBox(height: 12),
                    Text('Kural: $refundSummary'),
                  ],
                  if (refundAmountMinor != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'İade Tutarı: ${PaymentPresentationHelper.formatPrice(refundAmountMinor)}',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Talebi Gönder'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _requestRefund(BuildContext context, Payment payment) async {
    final confirmed = await _confirmRefund(context, payment);
    if (!context.mounted || !confirmed) {
      return;
    }

    try {
      final result = await context.read<PaymentListViewModel>().requestRefund(
        payment.reservationId,
      );
      if (!context.mounted || result == null) {
        return;
      }

      final message =
          '${result.refundSummary} Tahmini tutar: '
          '${PaymentPresentationHelper.formatPrice(result.refundAmountMinor)}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PaymentActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _approveRefund(BuildContext context, Payment payment) async {
    final refundRequestId = payment.refundRequestId;
    if (refundRequestId == null) {
      return;
    }
    final viewModel = context.read<PaymentListViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await viewModel.approveRefundRequest(refundRequestId);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('İade talebi onaylandı.')),
      );
    } on PaymentActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _rejectRefund(BuildContext context, Payment payment) async {
    final refundRequestId = payment.refundRequestId;
    if (refundRequestId == null) {
      return;
    }
    final viewModel = context.read<PaymentListViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (_) => const _RefundRejectDialog(),
    );

    if (!context.mounted || rejectionReason == null) {
      return;
    }

    try {
      await viewModel.rejectRefundRequest(
        refundRequestId: refundRequestId,
        rejectionReason: rejectionReason,
      );
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('İade talebi reddedildi.')),
      );
    } on PaymentActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PaymentListViewModel>();
    final screenContext = context;

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
                    if (departureLabel != null) Text('Kalkış: $departureLabel'),
                    Text(
                      'Tutar: ${PaymentPresentationHelper.formatPrice(payment.amountMinor)}',
                    ),
                    if (payment.paymentDeadlineAt != null)
                      Text(
                        'Ödeme Son Tarihi: ${PaymentPresentationHelper.formatDateTime(payment.paymentDeadlineAt!)}',
                      ),
                    if (payment.paidAt != null)
                      Text(
                        'Ödeme Zamanı: ${PaymentPresentationHelper.formatDateTime(payment.paidAt!)}',
                      ),
                    if (payment.reservationCancelledAt != null)
                      Text(
                        'İptal Zamanı: ${PaymentPresentationHelper.formatDateTime(payment.reservationCancelledAt!)}',
                      ),
                    if ((payment.companyName ?? '').trim().isNotEmpty)
                      Text('Firma: ${payment.companyName}'),
                    if (payment.refundAmountMinor != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'İade Tutarı: ${PaymentPresentationHelper.formatPrice(payment.refundAmountMinor!)}',
                      ),
                    ],
                    if (PaymentPresentationHelper.refundSummaryLabel(payment) !=
                        null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'İade Kuralı: ${PaymentPresentationHelper.refundSummaryLabel(payment)!}',
                        ),
                      ),
                    if (payment.refundRequestStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'İade Talebi: ${PaymentPresentationHelper.refundRequestStatusLabel(payment.refundRequestStatus!)}',
                      ),
                    ],
                    if ((payment.refundRequestRejectionReason ?? '')
                        .trim()
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'İade Red Nedeni: ${payment.refundRequestRejectionReason}',
                        ),
                      ),
                    if (viewModel.canOpenCheckout(payment)) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _openCheckout(screenContext, payment);
                              },
                        icon: const Icon(Icons.credit_card_outlined),
                        label: Text(
                          payment.status == PaymentStatus.failed
                              ? 'Tekrar Öde'
                              : 'Ödeme Yap',
                        ),
                      ),
                    ],
                    if (viewModel.canRequestRefund(payment)) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _requestRefund(screenContext, payment);
                              },
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('İade Talep Et'),
                      ),
                    ],
                    if (viewModel.canReviewRefund(payment)) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: viewModel.isBusy
                                  ? null
                                  : () {
                                      _approveRefund(screenContext, payment);
                                    },
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('İadeyi Onayla'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: viewModel.isBusy
                                  ? null
                                  : () {
                                      _rejectRefund(screenContext, payment);
                                    },
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reddet'),
                            ),
                          ),
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

class _RefundRejectDialog extends StatefulWidget {
  const _RefundRejectDialog();

  @override
  State<_RefundRejectDialog> createState() => _RefundRejectDialogState();
}

class _RefundRejectDialogState extends State<_RefundRejectDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İade Talebini Reddet'),
      content: TextField(
        controller: _reasonController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Red nedeni',
          hintText: 'Kısa bir açıklama yazın',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Vazgeç'),
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
