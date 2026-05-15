import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../models/enums.dart';

class HomeViewModel {
  HomeViewModel({required this.role, AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final UserRole role;
  final AuthRepository _authRepository;

  String get appBarTitle => switch (role) {
    UserRole.normalUser => 'Normal Kullanıcı Ana Sayfa',
    UserRole.companyOfficer => 'Firma Gorevlisi Ana Sayfa',
    UserRole.admin => 'Admin Ana Sayfa',
  };

  String get description => switch (role) {
    UserRole.normalUser =>
      'Yaklaşan ve yolda olan onaylı seferleri inceleyebilir, filtreleyebilir ve rezervasyon oluşturabilirsiniz.',
    UserRole.companyOfficer =>
      'Firma bilgilerinizi güncelleyip operasyon panelinden doluluk, yolcu ve sefer akışlarını takip edebilirsiniz.',
    UserRole.admin =>
      'Dashboard üzerinden bekleyen kayıtları, satış özetlerini ve red nedenlerini yönetebilirsiniz.',
  };

  String get tripButtonLabel => switch (role) {
    UserRole.normalUser => 'Tüm Seferleri Gör',
    UserRole.companyOfficer => 'Şirket Seferlerini Yönet',
    UserRole.admin => 'Seferleri Incele',
  };

  String get email => _authRepository.resolveEmail();
}
