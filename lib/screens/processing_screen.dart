import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'results_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _api = ApiService();
  int _activeStep = 0;
  double _progress = 0.08;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ticker = Stream.periodic(const Duration(milliseconds: 350), (i) => i);
    final sub = ticker.listen((_) {
      if (!mounted || _progress >= 0.85) return;
      setState(() {
        _progress = (_progress + 0.04).clamp(0.0, 0.85);
        if (_progress > 0.35 && _activeStep < 1) _activeStep = 1;
      });
    });

    try {
      final result = await _api.scanImage(widget.imageFile);
      if (!mounted) return;
      setState(() {
        _activeStep = 2;
        _progress = 1;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            imageFile: widget.imageFile,
            entities: result.entities,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
    } finally {
      await sub.cancel();
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.file(widget.imageFile, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StepRow(label: 'Extracting text with OCR...', done: _activeStep > 0, active: _activeStep == 0),
                  _StepRow(label: 'Analyzing with AI...', done: _activeStep > 1, active: _activeStep == 1),
                  _StepRow(label: 'Done!', done: _activeStep >= 2, active: _activeStep == 2),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: const Color(0x22FFFFFF),
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: active
                ? const CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent)
                : Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: done ? AppColors.success : AppColors.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: active || done ? AppColors.text : AppColors.textMuted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
