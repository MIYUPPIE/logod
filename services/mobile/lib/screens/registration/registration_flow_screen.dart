import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sync_providers.dart';
import 'registration_draft.dart';
import 'steps/business_step.dart';
import 'steps/gps_step.dart';
import 'steps/identity_step.dart';
import 'steps/review_step.dart';

const _stepTitles = ['Identity', 'Business', 'GPS', 'Review'];

class RegistrationFlowScreen extends ConsumerStatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  ConsumerState<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends ConsumerState<RegistrationFlowScreen> {
  final _draft = RegistrationDraft();
  int _stepIndex = 0;
  bool _saving = false;

  bool get _canContinue => switch (_stepIndex) {
        0 => _draft.identityComplete,
        1 => _draft.businessComplete,
        2 => _draft.gpsComplete,
        _ => true,
      };

  void _next() {
    if (_stepIndex < _stepTitles.length - 1) {
      setState(() => _stepIndex++);
    } else {
      _save();
    }
  }

  void _back() {
    if (_stepIndex > 0) {
      setState(() => _stepIndex--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final record = _draft.toSellerRecord();
    await ref.read(sellerRepositoryProvider).saveNewRegistration(record);
    await ref.read(syncControllerProvider.notifier).refreshPendingCounts();
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());

    if (!mounted) return;
    setState(() => _saving = false);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seller saved'),
        content: Text(
          'Saved on this device as ${record.displayId}.\n\n'
          'It will sync automatically once connectivity is available, or you '
          'can tap "Sync now" from the home screen.',
        ),
        actions: [
          FilledButton(
            key: const Key('registration_done_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register seller - ${_stepTitles[_stepIndex]}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_stepIndex + 1) / _stepTitles.length),
          Expanded(
            child: IndexedStack(
              index: _stepIndex,
              children: [
                IdentityStep(draft: _draft, onChanged: () => setState(() {})),
                BusinessStep(draft: _draft, onChanged: () => setState(() {})),
                GpsStep(draft: _draft, onChanged: () => setState(() {})),
                ReviewStep(draft: _draft),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('registration_next_button'),
                onPressed: (_canContinue && !_saving) ? _next : null,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_stepIndex == _stepTitles.length - 1 ? 'Save' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
