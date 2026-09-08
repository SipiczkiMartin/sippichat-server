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

      debugPrint('AUTH INITIALIZE: authenticated=$authenticated');
    } catch (e, stackTrace) {
      debugPrint("Auth initialization error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();
    }

    loading = false;

    debugPrint(
      'AUTH INITIALIZE COMPLETE: loading=$loading authenticated=$authenticated',
    );

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await authRepository.login(email, password);

      authenticated = true;

      debugPrint('LOGIN: authenticated=$authenticated');

      return true;
    } catch (e, stackTrace) {
      debugPrint("Login error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();

      return false;
    } finally {
      loading = false;

      debugPrint(
        'LOGIN COMPLETE: loading=$loading authenticated=$authenticated',
      );

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

      debugPrint('REGISTER: authenticated=$authenticated');

      debugPrint('REGISTER: notifyListeners will happen in finally');

      return true;
    } catch (e, stackTrace) {
      debugPrint("Registration error: $e");
      debugPrintStack(stackTrace: stackTrace);

      authenticated = false;
      error = e.toString();

      return false;
    } finally {
      loading = false;

      debugPrint(
        'REGISTER COMPLETE: loading=$loading authenticated=$authenticated',
      );

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

      debugPrint('LOGOUT: authenticated=$authenticated');

      notifyListeners();
    }
  }
}
