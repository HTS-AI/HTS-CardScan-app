import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'auth_scaffold.dart';
import 'verify_screen.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key, this.prefillEmail});

  final String? prefillEmail;

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if ((widget.prefillEmail ?? '').isNotEmpty) {
      _email.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your work email.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.forgot(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If that email is registered, we sent a 6-digit code.')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyScreen(email: email, purpose: 'reset'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'We will send a code to your organization mailbox.',
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Work email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            busy: _busy,
            label: 'Send reset code',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
