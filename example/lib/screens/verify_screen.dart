import 'dart:io';

import 'package:flutter/material.dart';
import 'package:idz_flutter/idz_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';

enum _Mode { document, identity, identityLive }

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  _Mode _mode = _Mode.document;
  File? _idFront;
  File? _idBack;
  File? _selfie;
  File? _video;
  bool _busy = false;
  Verification? _result;
  KycFailure? _failure;

  IdzFlutter? _sdk;

  IdzFlutter _ensureSdk() {
    final current = _sdk;
    if (current != null) return current;
    final sdk = IdzFlutter(
      config: IdzConfig(apiKey: AppConfig.apiKey, baseUrl: AppConfig.baseUrl),
    );
    _sdk = sdk;
    return sdk;
  }

  @override
  void dispose() {
    _sdk?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(File) sink) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    sink(File(picked.path));
    setState(() {});
  }

  Future<void> _pickVideo(void Function(File) sink) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    sink(File(picked.path));
    setState(() {});
  }

  bool get _canRun {
    if (!AppConfig.isReady) return false;
    if (_idFront == null || _idBack == null) return false;
    if (_mode != _Mode.document && _selfie == null) return false;
    if (_mode == _Mode.identityLive && _video == null) return false;
    return true;
  }

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() {
      _busy = true;
      _result = null;
      _failure = null;
    });
    final sdk = _ensureSdk();
    final docType = AppConfig.documentType;
    final idemKey = DateTime.now().microsecondsSinceEpoch.toString();

    final result = switch (_mode) {
      _Mode.document => await sdk.client.verifyDocument(
        idFront: _idFront!,
        idBack: _idBack!,
        documentType: docType,
        idempotencyKey: idemKey,
      ),
      _Mode.identity => await sdk.client.verifyIdentity(
        idFront: _idFront!,
        idBack: _idBack!,
        selfie: _selfie!,
        documentType: docType,
        idempotencyKey: idemKey,
      ),
      _Mode.identityLive => await sdk.client.verifyIdentityLive(
        idFront: _idFront!,
        idBack: _idBack!,
        selfie: _selfie!,
        video: _video!,
        documentType: docType,
        idempotencyKey: idemKey,
      ),
    };

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _failure = failure;
        _busy = false;
      }),
      (verification) => setState(() {
        _result = verification;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(value: _Mode.document, label: Text('Document')),
            ButtonSegment(value: _Mode.identity, label: Text('Identity')),
            ButtonSegment(
              value: _Mode.identityLive,
              label: Text('Identity + live'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Document type: ${AppConfig.documentType.wireValue}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 32),
        _filePicker(
          'ID front',
          _idFront,
          () => _pickImage((f) => _idFront = f),
        ),
        _filePicker('ID back', _idBack, () => _pickImage((f) => _idBack = f)),
        if (_mode != _Mode.document)
          _filePicker('Selfie', _selfie, () => _pickImage((f) => _selfie = f)),
        if (_mode == _Mode.identityLive)
          _filePicker('Video', _video, () => _pickVideo((f) => _video = f)),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Run verification'),
          onPressed: _busy || !_canRun ? null : _run,
        ),
        if (_failure != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _failure.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          KycResultCard(verification: _result!),
        ],
      ],
    );
  }

  Widget _filePicker(String label, File? file, VoidCallback pick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              file == null ? label : '$label: ${file.uri.pathSegments.last}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton(onPressed: pick, child: const Text('Pick')),
        ],
      ),
    );
  }
}
