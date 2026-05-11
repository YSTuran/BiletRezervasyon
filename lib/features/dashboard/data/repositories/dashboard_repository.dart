import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../domain/models/admin_dashboard.dart';
import '../../domain/models/company_operations_dashboard.dart';

class DashboardRepository {
  Future<CompanyOperationsDashboard> fetchCompanyOperationsDashboard() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getCompanyOperationsDashboard',
      );
      return CompanyOperationsDashboard.fromJson(_toMap(response));
    } on FirebaseFunctionsException catch (error) {
      throw DashboardActionException(
        _mapDashboardError(error.code, error.message),
      );
    }
  }

  Future<AdminDashboard> fetchAdminDashboard() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getAdminDashboard',
      );
      return AdminDashboard.fromJson(_toMap(response));
    } on FirebaseFunctionsException catch (error) {
      throw DashboardActionException(
        _mapDashboardError(error.code, error.message),
      );
    }
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) {
      if (data is Map) {
        return MapEntry('$key', _toMap(data));
      }
      if (data is List) {
        return MapEntry(
          '$key',
          data
              .map((item) => item is Map ? _toMap(item) : item)
              .toList(growable: false),
        );
      }
      return MapEntry('$key', data);
    });
  }

  String _mapDashboardError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'permission-denied':
        return 'Bu panele erismek icin yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Panel verileri su anda alinamadi. Lutfen tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Panel verileri yuklenemedi.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Panel verileri yuklenemedi.';
    }
  }
}

class DashboardActionException implements Exception {
  const DashboardActionException(this.message);

  final String message;
}
