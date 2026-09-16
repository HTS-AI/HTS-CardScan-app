import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/auth_service.dart';
import '../theme.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty && password.isEmpty) {
      showAppToast(context, 'Enter your email and password.');
      return;
    }
    if (email.isEmpty) {
      showAppToast(context, 'Enter your work email.');
      return;
    }
    if (password.isEmpty) {
      showAppToast(context, 'Enter your password.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      await AuthService.instance.login(_email.text, _password.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        showAppToast(context, e.message);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignupScreen(prefillEmail: _email.text.trim()),
          ),
        );
        return;
      }
      showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuthScaffold(
          title: 'Welcome back',
          subtitle: 'Sign in with your organization email to scan cards.',
          child: Column(
            children: [
              TextField(
                controller: _email,
                enabled: !_busy,
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
                enabled: !_busy,
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
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _appVersion.isEmpty ? '' : 'Version - $_appVersion',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
