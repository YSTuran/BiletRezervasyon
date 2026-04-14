import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/enums.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/company.dart';
import '../helpers/company_presentation_helper.dart';
import '../view_models/company_form_view_model.dart';

class CompanyFormScreen extends StatelessWidget {
  const CompanyFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          CompanyFormViewModel(repository: context.read<CompanyRepository>())
            ..load(),
      child: const _CompanyFormView(),
    );
  }
}

class _CompanyFormView extends StatefulWidget {
  const _CompanyFormView();

  @override
  State<_CompanyFormView> createState() => _CompanyFormViewState();
}

class _CompanyFormViewState extends State<_CompanyFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _seededCompanyId;

  CompanyFormViewModel get _viewModel => context.read<CompanyFormViewModel>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final company = await _viewModel.saveCompany(_nameController.text);
      if (!mounted || company == null) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firma bilgileri kaydedildi ve admin onayina gonderildi.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on CompanyFormException catch (error) {
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
    final viewModel = context.watch<CompanyFormViewModel>();
    final company = viewModel.company;

    if (_seededCompanyId != company?.id) {
      _seededCompanyId = company?.id;
      _nameController.text = company?.name ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Firma Bilgileri')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Firma profili',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Firma yetkilileri firma adini ve tek ulasim turunu tanimlar. Kayit sonrasi admin onayi gerekir.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (company != null) ...[
                          const SizedBox(height: 20),
                          _StatusCard(company: company),
                        ],
                        if (viewModel.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            viewModel.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Firma Adi',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Firma adi zorunludur';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TransportType>(
                          initialValue: viewModel.transportType,
                          decoration: const InputDecoration(
                            labelText: 'Ulasim Turu',
                            prefixIcon: Icon(Icons.alt_route),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TransportType.bus,
                              child: Text('Otobus'),
                            ),
                            DropdownMenuItem(
                              value: TransportType.flight,
                              child: Text('Ucak'),
                            ),
                          ],
                          onChanged: viewModel.isBusy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    viewModel.updateTransportType(value);
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Her firma yalnizca tek bir ulasim turu ile calisir. Sonradan degistirirseniz tekrar admin onayina gider.',
                          style: Theme.of(context).textTheme.bodySmall,
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
                                : const Text('Firma Bilgilerini Gonder'),
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
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final rejectionReason = (company.rejectionReason ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(company.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Durum: ${CompanyPresentationHelper.approvalLabel(company.status)}',
          ),
          Text(
            'Ulasim: ${CompanyPresentationHelper.transportLabel(company.transportType)}',
          ),
          if (rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Red nedeni: $rejectionReason',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
