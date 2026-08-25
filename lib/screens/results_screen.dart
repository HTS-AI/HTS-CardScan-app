import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entities.dart';
import '../theme.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.imageFile,
    required this.entities,
  });

  final File imageFile;
  final ContactEntities entities;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _org;
  late final TextEditingController _des;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _web;
  bool _saving = false;
  static const _contactsChannel = MethodChannel('cardscan/contacts');

  @override
  void initState() {
    super.initState();
    final e = widget.entities;
    _name = TextEditingController(text: e.name);
    _org = TextEditingController(text: e.org);
    _des = TextEditingController(text: e.des);
    _phone = TextEditingController(text: e.phone);
    _email = TextEditingController(text: e.email);
    _web = TextEditingController(text: e.web);
  }

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    _des.dispose();
    _phone.dispose();
    _email.dispose();
    _web.dispose();
    super.dispose();
  }

  ContactEntities get _current => ContactEntities(
        name: _name.text.trim(),
        org: _org.text.trim(),
        des: _des.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        web: _web.text.trim(),
      );

  Future<void> _copy() async {
    final text = _current.asCopyText();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to copy yet.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact details copied')),
    );
  }

  List<String> _splitValues(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _addToContacts() async {
    if (_saving) return;
    setState(() => _saving = true);

    final data = _current;
    final displayName = data.name.isEmpty ? 'Unknown' : data.name;
    final sites = _splitValues(data.web).map((e) {
      return (e.startsWith('http://') || e.startsWith('https://')) ? e : 'https://$e';
    }).toList();

    try {
      await _contactsChannel.invokeMethod('openContactEditor', {
        'name': displayName,
        'org': data.org,
        'title': data.des,
        'phones': _splitValues(data.phone),
        'emails': _splitValues(data.email),
        'websites': sites,
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.code == 'no_app'
          ? 'No Contacts app was found on this phone.'
          : 'Could not open Contacts. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Contacts. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.1,
                colors: [Color(0x22FF8C32), AppColors.bg],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Extracted Contact',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        child: const Text('Scan again'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 8,
                          child: Image.file(widget.imageFile, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Field(icon: Icons.person_outline, label: 'Name', controller: _name, hint: 'Full name'),
                      _Field(icon: Icons.apartment_outlined, label: 'Organization', controller: _org, hint: 'Company name'),
                      _Field(icon: Icons.work_outline, label: 'Designation', controller: _des, hint: 'Job title'),
                      _Field(icon: Icons.phone_outlined, label: 'Phone', controller: _phone, hint: 'Phone number', keyboard: TextInputType.phone),
                      _Field(icon: Icons.mail_outline, label: 'Email', controller: _email, hint: 'Email address', keyboard: TextInputType.emailAddress),
                      _Field(icon: Icons.language, label: 'Website', controller: _web, hint: 'Website URL', keyboard: TextInputType.url),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _addToContacts,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Add to Contacts', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboard,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0x22FF8C32),
              child: Icon(icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  TextField(
                    controller: controller,
                    keyboardType: keyboard,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
