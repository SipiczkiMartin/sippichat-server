import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/auth/web_register_page.dart';

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const String _rememberedEmailKey = 'remembered_email';

  bool _loading = false;
  bool _rememberEmail = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString(_rememberedEmailKey);

    debugPrint('REMEMBERED EMAIL: $email');

    if (!mounted || email == null || email.isEmpty) {
      return;
    }

    _emailController.text = email;

    debugPrint('REMEMBERED EMAIL: loaded into field');
  }

  Future<void> _login() async {
    if (_loading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    // Save the email before attempting login.
    // This makes sure it is available even if the auth flow
    // immediately rebuilds the page after successful login.
    final prefs = await SharedPreferences.getInstance();

    if (_rememberEmail) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    final success = await AppDependencies.authController.login(email, password);

    if (!mounted) return;

    if (success) {
      return;
    }

    final error = AppDependencies.authController.error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Something went wrong'),
        backgroundColor: Colors.redAccent,
      ),
    );

    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0D0F11);
    const card = Color(0xFF171A1F);
    const border = Color(0xFF292E35);
    const accent = Color(0xFF4F8CFF);

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.chat_bubble_rounded,
                    size: 48,
                    color: accent,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Sign in to continue to SippiChat',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),

                  const SizedBox(height: 32),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white54,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Checkbox(
                        value: _rememberEmail,
                        activeColor: accent,
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() {
                                  _rememberEmail = value ?? false;
                                });
                              },
                      ),
                      const Text(
                        'Remember email',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WebRegisterPage(),
                              ),
                            );
                          },
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
