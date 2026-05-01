import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/payment_repository.dart';
import '../helpers/payment_presentation_helper.dart';
import '../models/payment_route_arguments.dart';
import '../view_models/payment_checkout_view_model.dart';

class PaymentCheckoutScreen extends StatelessWidget {
  const PaymentCheckoutScreen({required this.arguments, super.key});

  final PaymentCheckoutArguments arguments;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaymentCheckoutViewModel(
        repository: context.read<PaymentRepository>(),
        reservationId: arguments.reservationId,
      )..load(),
      child: const _PaymentCheckoutView(),
    );
  }
}

class _PaymentCheckoutView extends StatefulWidget {
  const _PaymentCheckoutView();

  @override
  State<_PaymentCheckoutView> createState() => _PaymentCheckoutViewState();
}

class _PaymentCheckoutViewState extends State<_PaymentCheckoutView> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController(
    text: '4242 4242 4242 4242',
  );
  final _expiryMonthController = TextEditingController(text: '12');
  final _expiryYearController = TextEditingController(text: '30');
  final _cvvController = TextEditingController(text: '123');

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = context.read<PaymentCheckoutViewModel>();
    try {
      final result = await viewModel.submitFakePayment(
        cardHolderName: _cardHolderController.text,
        cardNumber: _cardNumberController.text,
        expiryMonth: _expiryMonthController.text,
        expiryYear: _expiryYearController.text,
        cvv: _cvvController.text,
      );
      if (!mounted || result == null) {
        return;
      }

      final message = result.succeeded
          ? 'Odeme basariyla tamamlandi.'
          : 'Odeme basarisiz oldu. Baska bir test karti deneyin.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (result.succeeded) {
        Navigator.of(context).pop(true);
      }
    } on PaymentActionException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PaymentCheckoutViewModel>();
    final payment = viewModel.payment;

    if (!viewModel.hasLoaded && viewModel.isBusy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (viewModel.errorMessage != null && payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Odeme')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(viewModel.errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (payment == null) {
      return const Scaffold(
        body: Center(child: Text('Odeme bilgisi bulunamadi.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Odeme')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                          PaymentPresentationHelper.routeLabel(payment),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (payment.tripCode != null)
                          Text('Sefer Kodu: ${payment.tripCode}'),
                        if (payment.seatNumber != null)
                          Text('Koltuk: ${payment.seatNumber}'),
                        if (payment.tripDepartureAt != null)
                          Text(
                            'Kalkis: ${PaymentPresentationHelper.formatDateTime(payment.tripDepartureAt!)}',
                          ),
                        Text(
                          'Tutar: ${PaymentPresentationHelper.formatPrice(payment.amountMinor)}',
                        ),
                        Text(
                          'Durum: ${PaymentPresentationHelper.statusLabel(payment.status)}',
                        ),
                        if (payment.paymentDeadlineAt != null)
                          Text(
                            'Odeme Son Tarihi: ${PaymentPresentationHelper.formatDateTime(payment.paymentDeadlineAt!)}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Test Kartlari',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Basarili odeme icin: 4242 4242 4242 4242'),
                        const Text('Basarisiz odeme icin: 4000 0000 0000 0002'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kart Bilgileri',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _cardHolderController,
                            decoration: const InputDecoration(
                              labelText: 'Kart Sahibi',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Kart sahibi zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _cardNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kart Numarasi',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                            ),
                            validator: (value) {
                              final normalized = (value ?? '').replaceAll(
                                ' ',
                                '',
                              );
                              if (!RegExp(r'^\d{16}$').hasMatch(normalized)) {
                                return 'Kart numarasi 16 haneli olmalidir';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _expiryMonthController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Ay',
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                  validator: (value) {
                                    final month = int.tryParse(
                                      (value ?? '').trim(),
                                    );
                                    if (month == null ||
                                        month < 1 ||
                                        month > 12) {
                                      return '01-12';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _expiryYearController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Yil',
                                    prefixIcon: Icon(Icons.event_outlined),
                                  ),
                                  validator: (value) {
                                    if (!RegExp(
                                      r'^\d{2,4}$',
                                    ).hasMatch((value ?? '').trim())) {
                                      return 'YY veya YYYY';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if (!RegExp(
                                r'^\d{3,4}$',
                              ).hasMatch((value ?? '').trim())) {
                                return '3 veya 4 hane';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed:
                                viewModel.isBusy || !viewModel.canSubmitPayment
                                ? null
                                : _submit,
                            icon: const Icon(Icons.payments_outlined),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: viewModel.isBusy
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Odemeyi Tamamla'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
