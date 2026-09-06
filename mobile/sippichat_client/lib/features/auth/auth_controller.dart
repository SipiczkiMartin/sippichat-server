import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'models/register_request.dart';

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

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await authRepository.login(email, password);

      authenticated = true;
      return true;
    } catch (e, stackTrace) {
      debugPrint("Login error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();

      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await authRepository.register(
        RegisterRequest(email: email, password: password),
      );

      authenticated = true;
      return true;
    } catch (e, stackTrace) {
      debugPrint("Registration error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();

      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await authRepository.logout();
    } catch (e, stackTrace) {
      debugPrint("Logout error: $e");
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      authenticated = false;
      error = null;

      notifyListeners();
    }
  }
}
