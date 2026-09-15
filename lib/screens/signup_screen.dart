import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'auth_scaffold.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.prefillEmail});

  final String? prefillEmail;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _hide = true;
  String? _signupToken;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    if ((widget.prefillEmail ?? '').isNotEmpty) {
      _email.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canResend => _resendSeconds <= 0;

  String get _resendLabel {
    if (_canResend) return 'Resend otp';
    final minutes = _resendSeconds ~/ 60;
    final seconds = _resendSeconds % 60;
    return 'Resend otp in $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 180);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _stopResendCooldown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSeconds = 0;
  }

  String get _title => switch (_step) {
        0 => 'Create account',
        1 => 'Verify email',
        _ => 'Set password',
      };

  String get _subtitle => switch (_step) {
        0 => 'Use your work mailbox. We will send a 6-digit otp first.',
        1 => 'Enter the otp we sent to ${_email.text.trim()}.',
        _ => 'Choose a password for ${_email.text.trim()}.',
      };

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0 && _email.text.trim().isEmpty) {
      showAppToast(context, 'Enter your work email.');
      return;
    }
    if (_step == 1 && _code.text.trim().length != 6) {
      showAppToast(context, 'Enter the 6-digit otp.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      if (_step == 0) {
        await AuthService.instance.signup(_email.text);
        if (!mounted) return;
        _code.clear();
        setState(() => _step = 1);
        _startResendCooldown();
      } else if (_step == 1) {
        final token = await AuthService.instance.verifyEmailCode(_email.text, _code.text);
        if (!mounted) return;
        if (token == null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
        setState(() {
          _signupToken = token;
          _step = 2;
        });
      } else {
        if (_password.text.length < 8) {
          showAppToast(context, 'Password must be at least 8 characters.');
          return;
        }
        if (_password.text != _confirm.text) {
          showAppToast(context, 'Passwords do not match.');
          return;
        }
        await AuthService.instance.completeSignup(
          _email.text,
          _signupToken ?? '',
          _password.text,
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBack() {
    if (_step == 2) {
      _stopResendCooldown();
      setState(() {
        _step = 0;
        _signupToken = null;
        _code.clear();
      });
      return;
    }
    if (_step > 0) {
      _stopResendCooldown();
      _code.clear();
      setState(() => _step -= 1);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    _code.clear();
    _startResendCooldown();
    try {
      final message = await AuthService.instance.resend(_email.text, 'verify');
      if (!mounted) return;
      showAppToast(context, message);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: AuthScaffold(
        title: _title,
        subtitle: _subtitle,
        step: _step,
        steps: 3,
        onBack: _goBack,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == 0)
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _next(),
              decoration: const InputDecoration(
                labelText: 'Work email',
                hintText: 'you@hyperthings.ai',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          if (_step == 1)
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit otp',
                counterText: '',
              ),
            ),
          if (_step == 2) ...[
            AuthPasswordField(
              controller: _password,
              label: 'Password (8+ characters)',
              obscure: _hide,
              onToggleObscure: () => setState(() => _hide = !_hide),
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _confirm,
              label: 'Confirm password',
              obscure: _hide,
              onToggleObscure: () => setState(() => _hide = !_hide),
              onSubmitted: (_) => _next(),
            ),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            busy: _busy,
            label: _step == 0
                ? 'Send otp'
                : _step == 1
                    ? 'Verify email'
                    : 'Save password',
            onPressed: _next,
          ),
            if (_step == 1)
            TextButton(
              onPressed: _canResend ? _resend : null,
              style: TextButton.styleFrom(
                disabledForegroundColor: AppColors.textSecondary,
              ),
              child: Text(_resendLabel),
            ),
        ],
      ),
    ),
    );
  }
}
