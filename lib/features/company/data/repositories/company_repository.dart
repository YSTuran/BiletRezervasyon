import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/data/services/postgres_callable_service.dart';
import '../../../../models/enums.dart';
import '../../domain/models/company.dart';

class CompanyRepository {
  CompanyRepository();

  final Map<String, Company> _companyCache = <String, Company>{};
  Company? _currentOfficerCompany;

  Company? get currentOfficerCompany => _currentOfficerCompany;

  bool get currentOfficerHasApprovedCompany =>
      currentOfficerCompany?.status == ApprovalStatus.approved;

  Future<List<Company>> fetchCompanies({ApprovalStatus? status}) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'listCompanies',
        data: {if (status != null) 'status': status.value},
      );

      final companies = _parseCompanies(response['companies']);
      for (final company in companies) {
        _companyCache[company.id] = company;
      }
      return companies;
    } on FirebaseFunctionsException catch (error) {
      throw CompanyActionException(_mapCompanyError(error.code, error.message));
    }
  }

  Future<Company?> fetchCurrentOfficerCompany() async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'getMyCompany',
      );
      final company = _parseCompany(response['company']);
      _currentOfficerCompany = company;
      if (company != null) {
        _companyCache[company.id] = company;
      }
      return company;
    } on FirebaseFunctionsException catch (error) {
      throw CompanyActionException(_mapCompanyError(error.code, error.message));
    }
  }

  Future<Company> saveCurrentOfficerCompany({
    required String name,
    required TransportType transportType,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const CompanyActionException('Firma adi zorunludur.');
    }

    try {
      final response = await PostgresCallableService.call(
        functionName: 'upsertCompanyProfile',
        data: {'name': trimmedName, 'transportType': transportType.value},
      );

      final company = _parseCompany(response['company']);
      if (company == null) {
        throw const CompanyActionException('Firma kaydı oluşturulamadı.');
      }

      _currentOfficerCompany = company;
      _companyCache[company.id] = company;
      return company;
    } on FirebaseFunctionsException catch (error) {
      throw CompanyActionException(_mapCompanyError(error.code, error.message));
    }
  }

  Future<Company?> approveCompany(String companyId) async {
    return _reviewCompany(
      companyId: companyId,
      status: ApprovalStatus.approved,
    );
  }

  Future<Company?> rejectCompany({
    required String companyId,
    required String rejectionReason,
  }) async {
    final trimmedReason = rejectionReason.trim();
    if (trimmedReason.isEmpty) {
      throw const CompanyActionException('Red nedeni zorunludur.');
    }

    return _reviewCompany(
      companyId: companyId,
      status: ApprovalStatus.rejected,
      rejectionReason: trimmedReason,
    );
  }

  Company? findCompanyById(String companyId) {
    return _companyCache[companyId];
  }

  Company? findCompanyByOfficerId(String officerUserId) {
    for (final company in _companyCache.values) {
      if (company.officerUserId == officerUserId) {
        return company;
      }
    }
    return null;
  }

  Future<Company?> _reviewCompany({
    required String companyId,
    required ApprovalStatus status,
    String? rejectionReason,
  }) async {
    try {
      final response = await PostgresCallableService.call(
        functionName: 'reviewCompany',
        data: {
          'companyId': companyId,
          'status': status.value,
          ...?rejectionReason == null
              ? null
              : {'rejectionReason': rejectionReason},
        },
      );

      final company = _parseCompany(response['company']);
      if (company != null) {
        _companyCache[company.id] = company;
        if (_currentOfficerCompany?.id == company.id) {
          _currentOfficerCompany = company;
        }
      }
      return company;
    } on FirebaseFunctionsException catch (error) {
      throw CompanyActionException(_mapCompanyError(error.code, error.message));
    }
  }

  Company? _parseCompany(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return Company.fromJson(_toMap(value));
  }

  List<Company> _parseCompanies(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((company) => Company.fromJson(_toMap(company)))
        .toList();
  }

  Map<String, dynamic> _toMap(Map value) {
    return value.map((key, data) => MapEntry('$key', data));
  }

  String _mapCompanyError(String code, String? message) {
    final trimmedMessage = (message ?? '').trim();

    switch (code) {
      case 'not-found':
        return 'Firma kaydı bulunamadı.';
      case 'permission-denied':
        return 'Bu işlem için yeterli yetkiniz bulunmuyor.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sunucuya ulaşılamadı. Lütfen daha sonra tekrar deneyin.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'internal':
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Firma işlemi tamamlanamadı.';
      default:
        if (trimmedMessage.isNotEmpty) {
          return trimmedMessage;
        }
        return 'Firma işlemi tamamlanamadı.';
    }
  }
}

class CompanyActionException implements Exception {
  const CompanyActionException(this.message);

  final String message;
}
