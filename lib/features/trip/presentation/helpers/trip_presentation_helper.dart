import 'package:flutter/material.dart';

import '../../../../models/enums.dart';
import '../../domain/models/trip.dart';

enum TripVisualState {
  pendingApproval,
  upcoming,
  enRoute,
  completed,
  cancelledByCompany,
  rejectedByAdmin,
}

class TripVisualStyle {
  const TripVisualStyle({
    required this.state,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final TripVisualState state;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
}

abstract final class TripPresentationHelper {
  static String transportLabel(TransportType transportType) {
    return switch (transportType) {
      TransportType.bus => 'Otobüs',
      TransportType.flight => 'Uçak',
    };
  }

  static String statusLabel(TripStatus status) {
    return switch (status) {
      TripStatus.pendingApproval => 'Onay Bekliyor',
      TripStatus.approved => 'Onaylandı',
      TripStatus.rejected => 'Reddedildi',
      TripStatus.cancelled => 'İptal Edildi',
    };
  }

  static TripVisualState resolveVisualState(Trip trip, {DateTime? now}) {
    return resolveVisualStateForValues(
      status: trip.status,
      departureAt: trip.departureAt,
      arrivalAt: trip.arrivalAt,
      now: now,
    );
  }

  static TripVisualState resolveVisualStateForValues({
    required TripStatus status,
    required DateTime departureAt,
    required DateTime arrivalAt,
    DateTime? now,
  }) {
    if (status == TripStatus.rejected) {
      return TripVisualState.rejectedByAdmin;
    }
    if (status == TripStatus.cancelled) {
      return TripVisualState.cancelledByCompany;
    }
    if (status == TripStatus.pendingApproval) {
      return TripVisualState.pendingApproval;
    }

    final referenceTime = now ?? DateTime.now();
    if (referenceTime.isBefore(departureAt)) {
      return TripVisualState.upcoming;
    }
    if (referenceTime.isBefore(arrivalAt)) {
      return TripVisualState.enRoute;
    }
    return TripVisualState.completed;
  }

  static TripVisualStyle visualStyleForValues({
    required TripStatus status,
    required DateTime departureAt,
    required DateTime arrivalAt,
    DateTime? now,
  }) {
    final state = resolveVisualStateForValues(
      status: status,
      departureAt: departureAt,
      arrivalAt: arrivalAt,
      now: now,
    );
    return _visualStyleForState(state);
  }

  static TripVisualStyle visualStyle(Trip trip, {DateTime? now}) {
    final state = resolveVisualState(trip, now: now);
    return _visualStyleForState(state);
  }

  static TripVisualStyle _visualStyleForState(TripVisualState state) {
    return switch (state) {
      TripVisualState.pendingApproval => const TripVisualStyle(
        state: TripVisualState.pendingApproval,
        label: 'Onay Bekliyor',
        backgroundColor: Color(0xFFE8EEFF),
        borderColor: Color(0xFF4B6BFB),
        foregroundColor: Color(0xFF1D2E8E),
      ),
      TripVisualState.upcoming => const TripVisualStyle(
        state: TripVisualState.upcoming,
        label: 'Henüz Yola Çıkmadı',
        backgroundColor: Color(0xFFE6F7EC),
        borderColor: Color(0xFF2D9E5E),
        foregroundColor: Color(0xFF0C5E31),
      ),
      TripVisualState.enRoute => const TripVisualStyle(
        state: TripVisualState.enRoute,
        label: 'Yolda',
        backgroundColor: Color(0xFFFFF2C9),
        borderColor: Color(0xFFE0A100),
        foregroundColor: Color(0xFF7D5600),
      ),
      TripVisualState.completed => const TripVisualStyle(
        state: TripVisualState.completed,
        label: 'Vardı ve Tamamlandı',
        backgroundColor: Color(0xFFFDE3E3),
        borderColor: Color(0xFFD94B4B),
        foregroundColor: Color(0xFF7E1E1E),
      ),
      TripVisualState.cancelledByCompany => const TripVisualStyle(
        state: TripVisualState.cancelledByCompany,
        label: 'Firma İptali',
        backgroundColor: Color(0xFFFCE4F2),
        borderColor: Color(0xFFE05C9D),
        foregroundColor: Color(0xFF8E285F),
      ),
      TripVisualState.rejectedByAdmin => const TripVisualStyle(
        state: TripVisualState.rejectedByAdmin,
        label: 'Admin Reddi',
        backgroundColor: Color(0xFFFFE6D5),
        borderColor: Color(0xFFF08A24),
        foregroundColor: Color(0xFF8A4A08),
      ),
    };
  }

  static String formatPrice(int priceMinor) {
    final price = (priceMinor / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '$price TL';
  }

  static String formatDateTime(DateTime value) {
    final day = '${value.day}'.padLeft(2, '0');
    final month = '${value.month}'.padLeft(2, '0');
    final year = value.year;
    final hour = '${value.hour}'.padLeft(2, '0');
    final minute = '${value.minute}'.padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  static String formatDate(DateTime value) {
    final day = '${value.day}'.padLeft(2, '0');
    final month = '${value.month}'.padLeft(2, '0');
    final year = value.year;
    return '$day.$month.$year';
  }

  static String formatDuration(Trip trip) {
    final duration = trip.arrivalAt.difference(trip.departureAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}sa ${minutes}dk';
  }

  static String formatDepartureCountdown(
    DateTime departureAt, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final remaining = departureAt.difference(referenceTime);
    if (remaining.isNegative) {
      return 'Kalkış başladı';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      return 'Kalkışa $days gün $hours saat kaldı';
    }
    if (hours > 0) {
      return 'Kalkışa $hours saat $minutes dakika kaldı';
    }
    if (minutes > 0) {
      return 'Kalkışa $minutes dakika kaldı';
    }
    return 'Kalkış çok yakında';
  }
}
