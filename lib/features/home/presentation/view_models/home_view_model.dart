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
      'Yaklasan ve yolda olan onayli seferleri inceleyebilir, filtreleyebilir ve rezervasyon olusturabilirsiniz.',
    UserRole.companyOfficer =>
      'Firma bilgilerinizi guncelleyip operasyon panelinden doluluk, yolcu ve sefer akislarini takip edebilirsiniz.',
    UserRole.admin =>
      'Dashboard uzerinden bekleyen kayitlari, satis ozetlerini ve red nedenlerini yonetebilirsiniz.',
  };

  String get tripButtonLabel => switch (role) {
    UserRole.normalUser => 'Tum Seferleri Gor',
    UserRole.companyOfficer => 'Sirket Seferlerini Yonet',
    UserRole.admin => 'Seferleri Incele',
  };

  String get email => _authRepository.resolveEmail();
}
