import 'dart:async';

import 'package:flutter/material.dart';

import '../helpers/trip_presentation_helper.dart';

class DepartureCountdownChip extends StatefulWidget {
  const DepartureCountdownChip({
    required this.departureAt,
    this.compact = false,
    super.key,
  });

  final DateTime departureAt;
  final bool compact;

  @override
  State<DepartureCountdownChip> createState() => _DepartureCountdownChipState();
}

class _DepartureCountdownChipState extends State<DepartureCountdownChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = TripPresentationHelper.formatDepartureCountdown(
      widget.departureAt,
    );
    return Chip(
      avatar: const Icon(Icons.schedule_outlined, size: 18),
      label: Text(widget.compact ? label.replaceFirst('Kalkışa ', '') : label),
    );
  }
}
