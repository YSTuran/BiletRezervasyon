import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../models/enums.dart';
import '../../data/repositories/trip_repository.dart';
import '../helpers/trip_presentation_helper.dart';
import '../models/trip_route_arguments.dart';
import '../view_models/trip_create_view_model.dart';

class TripCreateScreen extends StatelessWidget {
  const TripCreateScreen({required this.arguments, super.key});

  final TripCreateArguments arguments;

  @override
  Widget build(BuildContext context) {
    if (arguments.role != UserRole.companyOfficer) {
      return const Scaffold(
        body: Center(child: Text('Bu sayfa sadece firma gorevlileri icindir.')),
      );
    }

    return ChangeNotifierProvider(
      create: (context) =>
          TripCreateViewModel(repository: context.read<TripRepository>())
            ..load(),
      child: const _TripCreateView(),
    );
  }
}

class _TripCreateView extends StatefulWidget {
  const _TripCreateView();

  @override
  State<_TripCreateView> createState() => _TripCreateViewState();
}

class _TripCreateViewState extends State<_TripCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _seatCapacityController = TextEditingController(text: '32');
  final _priceController = TextEditingController(text: '850');

  DateTime? _departureAt;
  DateTime? _arrivalAt;

  TripCreateViewModel get _viewModel => context.read<TripCreateViewModel>();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _seatCapacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final initial = isDeparture
        ? (_departureAt ?? DateTime.now().add(const Duration(days: 1)))
        : (_arrivalAt ??
              (_departureAt ??
                  DateTime.now().add(const Duration(days: 1, hours: 2))));

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || pickedTime == null) {
      return;
    }

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isDeparture) {
        _departureAt = selectedDateTime;
        _arrivalAt ??= selectedDateTime.add(const Duration(hours: 2));
      } else {
        _arrivalAt = selectedDateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_departureAt == null || _arrivalAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalkis ve varis zamani secilmelidir.')),
      );
      return;
    }

    final seatCapacity = int.tryParse(_seatCapacityController.text.trim());
    final priceValue = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceValue);
    if (seatCapacity == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kapasite ve fiyat gecerli olmalidir.')),
      );
      return;
    }

    try {
      final trip = await _viewModel.createTrip(
        origin: _originController.text,
        destination: _destinationController.text,
        departureAt: _departureAt!,
        arrivalAt: _arrivalAt!,
        seatCapacity: seatCapacity,
        priceMinor: (price * 100).round(),
      );

      if (!mounted || trip == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sefer olusturuldu.')));
      Navigator.of(context).pop(trip.id);
    } on TripFormException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Secilmedi';
    }
    final day = '${value.day}'.padLeft(2, '0');
    final month = '${value.month}'.padLeft(2, '0');
    final year = value.year;
    final hour = '${value.hour}'.padLeft(2, '0');
    final minute = '${value.minute}'.padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TripCreateViewModel>();

    if (!viewModel.hasLoaded && viewModel.isBusy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!viewModel.canCreateTrip || viewModel.transportType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yeni Sefer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        viewModel.blockedMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.companyForm);
                        },
                        icon: const Icon(Icons.apartment_outlined),
                        label: const Text('Firma Bilgilerine Git'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Sefer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Firma gorevlisi sefer olusturma',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kayit edilen sefer admin onayina gonderilir.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ulasim Turu',
                          prefixIcon: Icon(Icons.alt_route),
                        ),
                        child: Text(
                          TripPresentationHelper.transportLabel(
                            viewModel.transportType!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Firma taniminiza gore sadece bu ulasim turunde sefer acabilirsiniz.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _originController,
                        decoration: const InputDecoration(
                          labelText: 'Kalkis',
                          prefixIcon: Icon(Icons.trip_origin),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Kalkis noktasi zorunludur';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Varis',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Varis noktasi zorunludur';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _pickDateTime(isDeparture: true);
                              },
                        icon: const Icon(Icons.event_outlined),
                        label: Text('Kalkis: ${_formatDateTime(_departureAt)}'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: viewModel.isBusy
                            ? null
                            : () {
                                _pickDateTime(isDeparture: false);
                              },
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text('Varis: ${_formatDateTime(_arrivalAt)}'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _seatCapacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Koltuk Kapasitesi',
                          prefixIcon: Icon(Icons.airline_seat_recline_normal),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Gecerli bir kapasite girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Fiyat (TL)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Gecerli bir fiyat girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: viewModel.isBusy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: viewModel.isBusy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Seferi Kaydet'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
