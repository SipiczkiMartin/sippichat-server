import 'package:flutter/foundation.dart';
import 'package:sippichat_client/features/auth/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository authRepository;

  AuthController(this.authRepository);

  bool loading = true;
  bool authenticated = false;
  String? error;

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      authenticated = await authRepository.restoreSession();
    } catch (e, stackTrace) {
      debugPrint("Auth initialization error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }
}