import '../../models/enums.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const homeResolver = '/home';
  static const homeNormalUser = '/home/normal-user';
  static const homeCompanyOfficer = '/home/company-officer';
  static const homeAdmin = '/home/admin';
  static const profile = '/profile';
  static const tripList = '/trips';
  static const tripDetail = '/trips/detail';
  static const tripCreate = '/trips/create';

  static String homeForRole(UserRole role) => switch (role) {
    UserRole.normalUser => homeNormalUser,
    UserRole.companyOfficer => homeCompanyOfficer,
    UserRole.admin => homeAdmin,
  };
}
