import 'package:flutter/material.dart';

import '../view_models/home_resolver_view_model.dart';

class HomeResolverScreen extends StatefulWidget {
  const HomeResolverScreen({super.key});

  @override
  State<HomeResolverScreen> createState() => _HomeResolverScreenState();
}

class _HomeResolverScreenState extends State<HomeResolverScreen> {
  @override
  void initState() {
    super.initState();
    _viewModel = HomeResolverViewModel();
    _resolveAndNavigate();
  }

  late final HomeResolverViewModel _viewModel;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
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
      },
    );
  }
}
