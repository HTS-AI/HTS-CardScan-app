import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'auth_scaffold.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.email,
    required this.purpose,
  });

  final String email;
  final String purpose;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  Timer? _resendTimer;
  int _resendSeconds = 180;

  bool get _isReset => widget.purpose == 'reset';
  bool get _canResend => _resendSeconds <= 0;

  String get _resendLabel {
    if (_canResend) return 'Resend otp';
    final minutes = _resendSeconds ~/ 60;
    final seconds = _resendSeconds % 60;
    return 'Resend otp in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), _onResendTick);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onResendTick(Timer timer) {
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
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 180);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), _onResendTick);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_code.text.trim().length != 6) {
      showAppToast(context, 'Enter the 6-digit code.');
      return;
    }
    if (_isReset) {
      if (_password.text.isEmpty) {
        showAppToast(context, 'Enter a new password.');
        return;
      }
      if (_password.text.length < 8) {
        showAppToast(context, 'Password must be at least 8 characters.');
        return;
      }
      if (_confirm.text.isEmpty) {
        showAppToast(context, 'Confirm your new password.');
        return;
      }
      if (_password.text != _confirm.text) {
        showAppToast(context, 'Passwords do not match.');
        return;
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      if (_isReset) {
        await AuthService.instance.reset(widget.email, _code.text, _password.text);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      await AuthService.instance.verify(widget.email, _code.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    _code.clear();
    _startResendCooldown();
    try {
      final message = await AuthService.instance.resend(widget.email, widget.purpose);
      if (!mounted) return;
      _code.clear();
      showAppToast(context, message);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _isReset ? 'New password' : 'Verify email',
      subtitle: _isReset
          ? 'Enter the otp we sent to ${widget.email}, then choose a new password.'
          : 'Enter the 6-digit otp we sent to ${widget.email}.',
      child: Column(
        children: [
          TextField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: const InputDecoration(labelText: '6-digit otp', counterText: ''),
          ),
          if (_isReset) ...[
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _password,
              label: 'New password (8+ characters)',
              obscure: _hidePassword,
              enabled: !_busy,
              onToggleObscure: () => setState(() => _hidePassword = !_hidePassword),
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              obscure: _hideConfirm,
              enabled: !_busy,
              onToggleObscure: () => setState(() => _hideConfirm = !_hideConfirm),
              onSubmitted: (_) => _submit(),
            ),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            busy: _busy,
            label: _isReset ? 'Save new password' : 'Verify',
            onPressed: _submit,
          ),
          TextButton(
            onPressed: _canResend ? _resend : null,
            style: TextButton.styleFrom(
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: Text(_resendLabel),
          ),
        ],
      ),
    );
  }
}
