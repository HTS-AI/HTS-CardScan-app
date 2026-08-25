import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'auth_scaffold.dart';
import 'forgot_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.login(_email.text, _password.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignupScreen(prefillEmail: _email.text.trim()),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in with your organization email to scan cards.',
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Work email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          AuthPasswordField(
            controller: _password,
            label: 'Password',
            obscure: _hide,
            onToggleObscure: () => setState(() => _hide = !_hide),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ForgotScreen(prefillEmail: _email.text.trim()),
                ),
              ),
              child: const Text('Forgot password?'),
            ),
          ),
          AuthPrimaryButton(
            busy: _busy,
            label: 'Sign in',
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
            child: const Text('New here? Create an account'),
          ),
        ],
      ),
    );
  }
}
