import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../models/enums.dart';

class HomeViewModel {
  HomeViewModel({required this.role, AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final UserRole role;
  final AuthRepository _authRepository;

  String get appBarTitle => switch (role) {
    UserRole.normalUser => 'Normal Kullanici Ana Sayfa',
    UserRole.companyOfficer => 'Firma Gorevlisi Ana Sayfa',
    UserRole.admin => 'Admin Ana Sayfa',
  };

  String get description => switch (role) {
    UserRole.normalUser =>
      'Onaylanmis tum seferleri inceleyebilir ve tur bazinda filtreleyebilirsiniz.',
    UserRole.companyOfficer =>
      'Firma bilgilerinizi girip admin onayi sonrasi yalnizca kendi seferlerinizi yonetebilirsiniz.',
    UserRole.admin =>
      'Firmalari ve seferleri inceleyip onay surecini yonetebilirsiniz.',
  };

  String get tripButtonLabel => switch (role) {
    UserRole.normalUser => 'Tum Seferleri Gor',
    UserRole.companyOfficer => 'Sirket Seferlerini Yonet',
    UserRole.admin => 'Seferleri Incele',
  };

  String get email => _authRepository.resolveEmail();
}
