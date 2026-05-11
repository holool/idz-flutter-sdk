import 'package:flutter/material.dart';
import 'package:idz_flutter/idz_flutter.dart';

import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late DocumentType _documentType;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: AppConfig.baseUrl);
    _apiKey = TextEditingController(text: AppConfig.apiKey);
    _documentType = AppConfig.documentType;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('API endpoint', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'https://api.idz.holool.dev',
          ),
        ),
        const SizedBox(height: 24),
        Text('API key', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Sent as Authorization: Bearer <key> on every request. '
          'Never ship a live key in a public client build.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKey,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'idz_test_…',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        Text(
          'Default document type',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<DocumentType>(
          segments: const [
            ButtonSegment(
              value: DocumentType.algerianNationalId,
              label: Text('National ID'),
            ),
            ButtonSegment(
              value: DocumentType.algerianDrivingLicense,
              label: Text('Driving licence'),
            ),
          ],
          selected: {_documentType},
          onSelectionChanged: (sel) async {
            setState(() => _documentType = sel.first);
            await AppConfig.saveDocumentType(sel.first);
          },
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await AppConfig.saveBaseUrl(_baseUrl.text.trim());
            await AppConfig.saveApiKey(_apiKey.text.trim());
            await AppConfig.saveDocumentType(_documentType);
            if (!mounted) return;
            messenger.showSnackBar(const SnackBar(content: Text('Saved')));
            setState(() {});
          },
        ),
      ],
    );
  }
}
