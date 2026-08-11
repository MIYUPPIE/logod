import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/location_service.dart';
import '../../../providers/service_providers.dart';
import '../registration_draft.dart';

class GpsStep extends ConsumerStatefulWidget {
  final RegistrationDraft draft;
  final VoidCallback onChanged;

  const GpsStep({super.key, required this.draft, required this.onChanged});

  @override
  ConsumerState<GpsStep> createState() => _GpsStepState();
}

class _GpsStepState extends ConsumerState<GpsStep> {
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.draft.lat == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    }
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).getCurrentFix();
      setState(() {
        widget.draft.lat = fix.lat;
        widget.draft.lng = fix.lng;
        widget.draft.gpsAccuracy = fix.accuracy;
        widget.draft.gpsCapturedAt = fix.capturedAt;
      });
      widget.onChanged();
    } on LocationServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not capture GPS location.');
    } finally {
      setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasFix = draft.lat != null;
    final lowAccuracy =
        hasFix && (draft.gpsAccuracy ?? 0) > AppConfig.gpsAccuracyWarningThresholdMeters;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('GPS location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_capturing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasFix)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latitude: ${draft.lat!.toStringAsFixed(6)}'),
                  Text('Longitude: ${draft.lng!.toStringAsFixed(6)}'),
                  Text(
                    'Accuracy: ~${draft.gpsAccuracy?.toStringAsFixed(0) ?? '?'} m',
                    style: TextStyle(color: lowAccuracy ? Colors.orange.shade800 : null),
                  ),
                  if (lowAccuracy) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Accuracy is low. Move to open ground and recapture for a more precise location.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('recapture_gps_button'),
          onPressed: _capturing ? null : _capture,
          icon: const Icon(Icons.gps_fixed),
          label: Text(hasFix ? 'Recapture location' : 'Capture location'),
        ),
      ],
    );
  }
}
