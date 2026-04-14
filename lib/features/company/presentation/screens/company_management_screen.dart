import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/enums.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/company.dart';
import '../helpers/company_presentation_helper.dart';
import '../view_models/company_list_view_model.dart';

class CompanyManagementScreen extends StatelessWidget {
  const CompanyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          CompanyListViewModel(repository: context.read<CompanyRepository>())
            ..load(),
      child: const _CompanyManagementView(),
    );
  }
}

class _CompanyManagementView extends StatelessWidget {
  const _CompanyManagementView();

  Future<void> _approveCompany(BuildContext context, Company company) async {
    try {
      await context.read<CompanyListViewModel>().approveCompany(company.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${company.name} onaylandi.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Firma onaylanamadi.')));
    }
  }

  Future<void> _rejectCompany(BuildContext context, Company company) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${company.name} firmasini reddet'),
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
      await context.read<CompanyListViewModel>().rejectCompany(
        company.id,
        reason,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${company.name} reddedildi.')));
    } on CompanyReviewException catch (error) {
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
      ).showSnackBar(const SnackBar(content: Text('Firma reddedilemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CompanyListViewModel>();

    Widget body;
    if (viewModel.isBusy && viewModel.companies.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.errorMessage != null && viewModel.companies.isEmpty) {
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
    } else if (viewModel.companies.isEmpty) {
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
          itemCount: viewModel.companies.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final company = viewModel.companies[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Durum: ${CompanyPresentationHelper.approvalLabel(company.status)}',
                    ),
                    Text(
                      'Ulasim: ${CompanyPresentationHelper.transportLabel(company.transportType)}',
                    ),
                    Text('Yetkili ID: ${company.officerUserId}'),
                    if (viewModel.showsReviewActions) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: viewModel.isBusy
                                  ? null
                                  : () {
                                      _approveCompany(context, company);
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
                                      _rejectCompany(context, company);
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
      appBar: AppBar(title: const Text('Firma Yonetimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed:
                        viewModel.selectedStatus == ApprovalStatus.pending
                        ? null
                        : () {
                            viewModel.updateSelectedStatus(
                              ApprovalStatus.pending,
                            );
                            viewModel.load();
                          },
                    child: const Text('Onay Bekleyenler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed:
                        viewModel.selectedStatus == ApprovalStatus.approved
                        ? null
                        : () {
                            viewModel.updateSelectedStatus(
                              ApprovalStatus.approved,
                            );
                            viewModel.load();
                          },
                    child: const Text('Onaylananlar'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
