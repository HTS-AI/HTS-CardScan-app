import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
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
  bool _hide = true;

  bool get _isReset => widget.purpose == 'reset';

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_code.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code.')),
      );
      return;
    }
    if (_isReset) {
      if (_password.text.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 8 characters.')),
        );
        return;
      }
      if (_password.text != _confirm.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      if (_isReset) {
        await AuthService.instance.reset(widget.email, _code.text, _password.text);
      } else {
        await AuthService.instance.verify(widget.email, _code.text);
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService.instance.resend(widget.email, widget.purpose);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code was sent.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _isReset ? 'New password' : 'Verify email',
      subtitle: _isReset
          ? 'Enter the code we sent to ${widget.email}, then choose a new password.'
          : 'Enter the 6-digit code we sent to ${widget.email}.',
      child: Column(
        children: [
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
          ),
          if (_isReset) ...[
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _password,
              label: 'New password (8+ characters)',
              obscure: _hide,
              onToggleObscure: () => setState(() => _hide = !_hide),
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              obscure: _hide,
              onToggleObscure: () => setState(() => _hide = !_hide),
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
            onPressed: _resend,
            child: const Text('Resend code'),
          ),
        ],
      ),
    );
  }
}
