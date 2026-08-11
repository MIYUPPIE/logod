import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../registration_draft.dart';

class ReviewStep extends StatelessWidget {
  final RegistrationDraft draft;

  const ReviewStep({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (draft.photoPath != null)
          Center(
            child: CircleAvatar(radius: 48, backgroundImage: FileImage(File(draft.photoPath!))),
          ),
        const SizedBox(height: 16),
        _section('Identity', [
          _row('Full name', draft.fullName),
          _row('Phone', draft.phone),
          _row('NIN', (draft.nin == null || draft.nin!.isEmpty) ? '-' : draft.nin!),
          _row('DOB', draft.dob == null ? '-' : DateFormat('yyyy-MM-dd').format(draft.dob!)),
          _row('Gender', draft.gender ?? '-'),
        ]),
        _section('Business', [
          _row('Business name', draft.businessName),
          _row('Category', draft.businessCategory),
          _row('Shop no.', draft.shopNumber ?? '-'),
          _row('State', draft.stateName ?? '-'),
          _row('LGA', draft.lgaName ?? '-'),
          _row('Ward', draft.wardName ?? '-'),
          _row('Market', draft.marketName ?? '-'),
        ]),
        _section('GPS', [
          _row('Latitude', draft.lat?.toStringAsFixed(6) ?? '-'),
          _row('Longitude', draft.lng?.toStringAsFixed(6) ?? '-'),
          _row('Accuracy', draft.gpsAccuracy == null ? '-' : '~${draft.gpsAccuracy!.toStringAsFixed(0)} m'),
        ]),
        const SizedBox(height: 8),
        const Text(
          'This record will be saved on this device now and uploaded automatically '
          'once you have connectivity, or when you tap "Sync now".',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...rows,
              ],
            ),
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
