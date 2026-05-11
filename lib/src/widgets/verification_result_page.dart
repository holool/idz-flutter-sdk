import 'package:flutter/material.dart';

import '../client/idz_api_client.dart';
import '../models/verification.dart';
import 'result/artifacts_tab.dart';
import 'result/fields_tab.dart';

/// Tabbed result viewer for a single [Verification].
///
/// Renders two tabs:
///   - **Fields** — tabular view of every OCR field, plus a special MRZ
///     section, soft cross-check disagreement badges, and any
///     `metadata.postprocess_notes` hints.
///   - **Artifacts** — sectioned thumbnail grid backed by
///     `GET /v1/verifications/{id}/artifacts`. Lazy-loads bytes per
///     thumbnail through [IdzApiClient.getArtifactBytes] (cached
///     per session).
///
/// Tab state persists for the lifetime of the page.
///
/// `apps` use it as a drop-in for [KycResultCard] when they want the
/// fuller display:
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => VerificationResultPage(
///     verification: result,
///     client: idz.client,
///   ),
/// ));
/// ```
class VerificationResultPage extends StatefulWidget {
  const VerificationResultPage({
    super.key,
    required this.verification,
    required this.client,
    this.appBar = true,
    this.initialTab = VerificationResultTab.fields,
  });

  /// The verification to render. Should be the full detail-shape one
  /// (with `document.fields` populated) — the list-shape from
  /// `listVerifications` won't have OCR fields.
  final Verification verification;

  /// SDK client used for artifact byte loads.
  final IdzApiClient client;

  /// Whether to wrap the page in a Scaffold + AppBar. Set to false if
  /// you're embedding inside an existing Scaffold (e.g. inside a wizard
  /// step).
  final bool appBar;

  final VerificationResultTab initialTab;

  @override
  State<VerificationResultPage> createState() => _VerificationResultPageState();
}

enum VerificationResultTab { fields, artifacts }

class _VerificationResultPageState extends State<VerificationResultPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _controller,
            tabs: const [
              Tab(text: 'Fields'),
              Tab(text: 'Artifacts'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              FieldsTab(verification: widget.verification),
              ArtifactsTab(
                client: widget.client,
                verificationId: widget.verification.id,
              ),
            ],
          ),
        ),
      ],
    );

    if (!widget.appBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(widget.verification.id), elevation: 0),
      body: body,
    );
  }
}
