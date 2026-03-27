import '../../../../core/presentation/view_models/base_view_model.dart';
import '../../data/repositories/auth_repository.dart';

class HomeResolverViewModel extends BaseViewModel {
  HomeResolverViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  Future<NavigationInstruction?> resolveRoute() async {
    if (isBusy) {
      return null;
    }

    setBusy(true);
    try {
      return await _authRepository.resolveHomeRoute();
    } finally {
      setBusy(false);
    }
  }
}
