import '../../../../models/enums.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../domain/models/company.dart';

class CompanyRepository {
  CompanyRepository({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;
  final List<Company> _companies = [];

  Company? get currentOfficerCompany {
    final officerUserId = _authRepository.resolveCurrentUserId();
    if (officerUserId == null || officerUserId.isEmpty) {
      return null;
    }
    return findCompanyByOfficerId(officerUserId);
  }

  bool get currentOfficerHasApprovedCompany =>
      currentOfficerCompany?.status == ApprovalStatus.approved;

  Future<List<Company>> fetchCompanies({ApprovalStatus? status}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final filteredCompanies = status == null
        ? List<Company>.from(_companies)
        : _companies.where((company) => company.status == status).toList();

    filteredCompanies.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<Company>.unmodifiable(filteredCompanies);
  }

  Future<Company?> fetchCurrentOfficerCompany() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return currentOfficerCompany;
  }

  Future<Company> saveCurrentOfficerCompany({
    required String name,
    required TransportType transportType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const CompanyActionException('Firma adi zorunludur.');
    }

    final officerUserId = _requireCurrentUserId();
    final now = DateTime.now();
    final existingCompany = findCompanyByOfficerId(officerUserId);

    if (existingCompany == null) {
      final createdCompany = Company(
        id: 'company-${now.microsecondsSinceEpoch}',
        name: trimmedName,
        officerUserId: officerUserId,
        transportType: transportType,
        status: ApprovalStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      _companies.add(createdCompany);
      return createdCompany;
    }

    final updatedCompany = existingCompany.copyWith(
      name: trimmedName,
      transportType: transportType,
      status: ApprovalStatus.pending,
      reviewedByAdminId: null,
      reviewedAt: null,
      rejectionReason: null,
      updatedAt: now,
    );

    final index = _companies.indexWhere(
      (company) => company.id == existingCompany.id,
    );
    _companies[index] = updatedCompany;
    return updatedCompany;
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
    for (final company in _companies) {
      if (company.id == companyId) {
        return company;
      }
    }
    return null;
  }

  Company? findCompanyByOfficerId(String officerUserId) {
    for (final company in _companies) {
      if (company.officerUserId == officerUserId) {
        return company;
      }
    }
    return null;
  }

  String _requireCurrentUserId() {
    final userId = _authRepository.resolveCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw const CompanyActionException('Aktif kullanici bulunamadi.');
    }
    return userId;
  }

  Future<Company?> _reviewCompany({
    required String companyId,
    required ApprovalStatus status,
    String? rejectionReason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final index = _companies.indexWhere((company) => company.id == companyId);
    if (index < 0) {
      return null;
    }

    final reviewerId = _requireCurrentUserId();
    final currentCompany = _companies[index];
    final now = DateTime.now();
    final updatedCompany = currentCompany.copyWith(
      status: status,
      reviewedByAdminId: reviewerId,
      reviewedAt: now,
      rejectionReason: status == ApprovalStatus.rejected
          ? rejectionReason
          : null,
      updatedAt: now,
    );

    _companies[index] = updatedCompany;
    return updatedCompany;
  }
}

class CompanyActionException implements Exception {
  const CompanyActionException(this.message);

  final String message;
}
