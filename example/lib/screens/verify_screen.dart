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

class _VerifyScreenState extends State<VerifyScreen>
    with WidgetsBindingObserver {
  _Mode _mode = _Mode.document;
  File? _idFront;
  File? _idBack;
  File? _selfie;
  File? _video;
  bool _busy = false;
  bool _refreshing = false;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sdk?.dispose();
    super.dispose();
  }

  /// SDK is async now: a row that came back from POST as `in_progress`
  /// flips to a terminal status on the server some time later. Refresh
  /// when the app comes back to the foreground so the user sees the
  /// up-to-date verdict without having to pull manually.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefresh();
    }
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

    // No idempotencyKey passed — the SDK auto-generates a v4 UUID per
    // POST and sends it on the header. Real apps that want submit-retry
    // replay should hold their own key and pass it here.
    final result = switch (_mode) {
      _Mode.document => await sdk.client.verifyDocument(
        idFront: _idFront!,
        idBack: _idBack!,
        documentType: docType,
      ),
      _Mode.identity => await sdk.client.verifyIdentity(
        idFront: _idFront!,
        idBack: _idBack!,
        selfie: _selfie!,
        documentType: docType,
      ),
      _Mode.identityLive => await sdk.client.verifyIdentityLive(
        idFront: _idFront!,
        idBack: _idBack!,
        selfie: _selfie!,
        video: _video!,
        documentType: docType,
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

  /// Refresh the current row through `fetchVerification`. No-ops when
  /// there's nothing to refresh or the row is already terminal-and-not-
  /// under-review (no further mutations expected).
  Future<void> _refresh() async {
    final current = _result;
    if (current == null) return;
    // `under review` is terminal at the pipeline level but the reviewer
    // can still flip it, so we keep refreshing in that state too.
    if (current.isTerminal && !current.isUnderReview) return;
    setState(() => _refreshing = true);
    final sdk = _ensureSdk();
    final next = await sdk.client.fetchVerification(current.id);
    if (!mounted) return;
    next.fold(
      (_) => setState(() => _refreshing = false),
      (v) => setState(() {
        _result = v;
        _refreshing = false;
      }),
    );
  }

  void _maybeRefresh() {
    if (_busy || _refreshing) return;
    if (_result == null) return;
    _refresh();
  }

  void _handleAction(UserAction action) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('SDK suggested action: ${action.wireValue}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
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
            _filePicker(
              'Selfie',
              _selfie,
              () => _pickImage((f) => _selfie = f),
            ),
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
            _ResultHeader(
              verification: _result!,
              refreshing: _refreshing,
              onRefresh: _refresh,
            ),
            KycResultCard(verification: _result!, onAction: _handleAction),
          ],
        ],
      ),
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

/// Compact strip above the result card: VerdictChip on the left (the
/// SDK's canonical five-state pill), and on the right either a "refresh"
/// button (for non-terminal rows the user might want to advance) or a
/// spinner while the GET is in flight. Hint text underneath nudges the
/// user toward pull-to-refresh when the row is still in flight.
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.verification,
    required this.refreshing,
    required this.onRefresh,
  });

  final Verification verification;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canRefresh = verification.isInProgress || verification.isUnderReview;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VerdictChip(verification: verification),
              const Spacer(),
              if (refreshing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (canRefresh)
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
            ],
          ),
          if (verification.isInProgress) ...[
            const SizedBox(height: 4),
            Text(
              'Pull to refresh, or wait — we will auto-refresh when the app comes back to the foreground.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          Text(
            'ID: ${verification.id}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
