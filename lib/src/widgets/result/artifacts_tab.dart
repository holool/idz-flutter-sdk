import 'package:flutter/material.dart';

import '../../client/idz_api_client.dart';
import '../../models/artifacts_catalog.dart';
import '_result_tokens.dart';
import 'artifact_thumb.dart';

/// Artifacts tab — fetches the catalog on first build, then lays it out
/// as vertical sections, each a horizontal-scrolling thumbnail strip.
///
/// Lazy loading is implicit: thumbnails inside `ListView` only build
/// when scrolled into view, and each thumb fires its HTTP fetch on
/// first build (with shared in-memory cache thereafter).
class ArtifactsTab extends StatefulWidget {
  const ArtifactsTab({
    super.key,
    required this.client,
    required this.verificationId,
  });

  final IdzApiClient client;
  final String verificationId;

  @override
  State<ArtifactsTab> createState() => _ArtifactsTabState();
}

class _ArtifactsTabState extends State<ArtifactsTab> {
  late Future<ArtifactsCatalog?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ArtifactsCatalog?> _load() async {
    final result = await widget.client.getArtifactsCatalog(
      widget.verificationId,
    );
    return result.fold<ArtifactsCatalog?>((_) => null, (cat) => cat);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ArtifactsCatalog?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data;
          if (catalog == null) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Text(
                    'Could not load artifacts. Pull to retry.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(ResultTokens.sectionGap),
            children: _buildSections(context, catalog),
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, ArtifactsCatalog c) {
    final sections = <Widget>[];

    // Uploads — split by side for readability.
    final uploadFront = c.uploads.where((a) => a.side == 'front').toList();
    final uploadBack = c.uploads.where((a) => a.side == 'back').toList();
    final uploadOther = c.uploads
        .where((a) => a.side != 'front' && a.side != 'back')
        .toList();

    if (uploadFront.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Uploads — Front',
          items: uploadFront,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }
    if (uploadBack.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Uploads — Back',
          items: uploadBack,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }
    if (uploadOther.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Uploads',
          items: uploadOther,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }

    if (c.detections.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Detections',
          items: c.detections,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }

    if (c.crops.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Crops',
          items: c.crops,
          client: widget.client,
          verificationId: widget.verificationId,
          fallbackLabel: (i) => 'Crop ${i + 1}',
        ),
      );
    }

    if (c.faceMatch != null) {
      sections.add(
        _FaceMatchSection(
          face: c.faceMatch!,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }

    if (c.liveness.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Liveness',
          items: c.liveness,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }

    if (c.other.isNotEmpty) {
      sections.add(
        _Strip(
          title: 'Other',
          items: c.other,
          client: widget.client,
          verificationId: widget.verificationId,
        ),
      );
    }

    if (sections.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No artifacts available.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    return sections;
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.title,
    required this.items,
    required this.client,
    required this.verificationId,
    this.fallbackLabel,
  });

  final String title;
  final List<ArtifactItem> items;
  final IdzApiClient client;
  final String verificationId;
  final String Function(int index)? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ResultTokens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final label =
                    item.fieldName ??
                    (fallbackLabel != null
                        ? fallbackLabel!(i)
                        : item.category ?? '');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtifactThumb(
                      client: client,
                      verificationId: verificationId,
                      artifactId: item.id,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArtifactViewer(
                            client: client,
                            verificationId: verificationId,
                            artifactId: item.id,
                            title: label,
                          ),
                        ),
                      ),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 96,
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceMatchSection extends StatelessWidget {
  const _FaceMatchSection({
    required this.face,
    required this.client,
    required this.verificationId,
  });

  final FaceMatchArtifacts face;
  final IdzApiClient client;
  final String verificationId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: ResultTokens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Face match',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (face.selfieCrop != null)
                      ArtifactThumb(
                        client: client,
                        verificationId: verificationId,
                        artifactId: face.selfieCrop!.id,
                        size: 132,
                      )
                    else
                      _PlaceholderTile(label: 'No selfie'),
                    const SizedBox(height: 4),
                    Text(
                      'Selfie',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    if (face.documentFaceCrop != null)
                      ArtifactThumb(
                        client: client,
                        verificationId: verificationId,
                        artifactId: face.documentFaceCrop!.id,
                        size: 132,
                      )
                    else
                      _PlaceholderTile(label: 'No ID photo'),
                    const SizedBox(height: 4),
                    Text(
                      'ID photo',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (face.similarity != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Similarity ${(face.similarity! * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (face.other.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Strip(
              title: 'Other face artifacts',
              items: face.other,
              client: client,
              verificationId: verificationId,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
