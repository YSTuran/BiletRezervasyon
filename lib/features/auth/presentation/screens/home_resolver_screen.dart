import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../view_models/home_resolver_view_model.dart';

class HomeResolverScreen extends StatelessWidget {
  const HomeResolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          HomeResolverViewModel(authRepository: context.read<AuthRepository>()),
      child: const _HomeResolverView(),
    );
  }
}

class _HomeResolverView extends StatefulWidget {
  const _HomeResolverView();

  @override
  State<_HomeResolverView> createState() => _HomeResolverViewState();
}

class _HomeResolverViewState extends State<_HomeResolverView> {
  HomeResolverViewModel get _viewModel => context.read<HomeResolverViewModel>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAndNavigate();
    });
  }

  Future<void> _resolveAndNavigate() async {
    final instruction = await _viewModel.resolveRoute();

    if (!mounted || instruction == null) {
      return;
    }

    if (instruction.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(instruction.message!)));
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(instruction.route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<HomeResolverViewModel>();

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Rol bilgisi kontrol ediliyor...'),
          ],
        ),
      ),
    );
  }
}
