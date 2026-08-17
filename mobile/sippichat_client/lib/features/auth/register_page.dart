import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/core/errors/app_exception.dart';
import 'package:sippichat_client/features/auth/models/register_request.dart';
import 'package:sippichat_client/features/conversations/conversations_page.dart';

class RegisterPage extends StatefulWidget{
  const RegisterPage({super.key})

  ;@override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>{
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  Future<void> _register() async {
    setState(() {
      _loading = true;
    });
    try {
      await AppDependencies.authRepository.register(
          RegisterRequest(email: _emailController.text.trim(),
              password: _passwordController.text.trim())
      );

      if (!mounted) return;

      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ConversationsPage()));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e is AppException ? e.message : "Something went wrong!"),
            backgroundColor: Colors.red,
          )
      );
    } finally {
      if (mounted){
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'password'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _loading ? null : _register,
                  child: _loading ? const SizedBox(
                    width: 20,
                      height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Register'),
              ),
            )
          ],
        ),
      ),
    );
  }

}