import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/service_providers.dart';
import '../registration_draft.dart';

class IdentityStep extends ConsumerStatefulWidget {
  final RegistrationDraft draft;
  final VoidCallback onChanged;

  const IdentityStep({super.key, required this.draft, required this.onChanged});

  @override
  ConsumerState<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends ConsumerState<IdentityStep> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.draft.fullName);
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.draft.phone);
  late final TextEditingController _ninController =
      TextEditingController(text: widget.draft.nin ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final path = await ref.read(photoServiceProvider).captureFromCamera();
    if (path != null) {
      setState(() => widget.draft.photoPath = path);
      widget.onChanged();
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.draft.dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => widget.draft.dob = picked);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Identity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            key: const Key('capture_photo_button'),
            onTap: _capturePhoto,
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: draft.photoPath != null ? FileImage(File(draft.photoPath!)) : null,
              child: draft.photoPath == null
                  ? const Icon(Icons.camera_alt, size: 32, color: Colors.black54)
                  : null,
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _capturePhoto,
            child: Text(draft.photoPath == null ? 'Take seller photo' : 'Retake photo'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('full_name_field'),
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Full name *', border: OutlineInputBorder()),
          onChanged: (value) {
            draft.fullName = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('phone_field'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number *', border: OutlineInputBorder()),
          onChanged: (value) {
            draft.phone = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('nin_field'),
          controller: _ninController,
          keyboardType: TextInputType.number,
          maxLength: 11,
          decoration: const InputDecoration(
            labelText: 'NIN (optional, 11 digits)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            draft.nin = value;
            widget.onChanged();
          },
        ),
        InkWell(
          key: const Key('dob_field'),
          onTap: _pickDob,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date of birth *', border: OutlineInputBorder()),
            child: Text(
              draft.dob == null ? 'Select date' : DateFormat('yyyy-MM-dd').format(draft.dob!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('gender_field'),
          initialValue: draft.gender,
          decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() => draft.gender = value);
            widget.onChanged();
          },
        ),
      ],
    );
  }
}
