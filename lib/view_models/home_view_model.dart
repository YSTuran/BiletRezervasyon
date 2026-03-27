import '../models/enums.dart';
import '../repositories/auth_repository.dart';

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
    UserRole.normalUser => 'Bu sayfa normal kullaniciya ait home screen.',
    UserRole.companyOfficer => 'Bu sayfa firma gorevlisine ait home screen.',
    UserRole.admin => 'Bu sayfa admin kullaniciya ait home screen.',
  };

  String get email => _authRepository.resolveEmail();
}
