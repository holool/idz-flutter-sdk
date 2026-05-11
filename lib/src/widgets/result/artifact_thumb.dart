import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../client/idz_api_client.dart';

/// In-memory cache shared across all `ArtifactThumb` instances.
///
/// Keyed by `(verificationId, artifactId)`. Bytes are immutable on the
/// server side (artifact ids are content-addressed), so caching forever
/// per-session is safe. Cleared on app restart — that's good enough for
/// a result viewer.
class _ArtifactBytesCache {
  static final Map<String, Uint8List> _store = <String, Uint8List>{};

  static Uint8List? get(String verificationId, String artifactId) {
    return _store['$verificationId/$artifactId'];
  }

  static void put(String verificationId, String artifactId, Uint8List bytes) {
    _store['$verificationId/$artifactId'] = bytes;
  }
}

/// Auth-aware thumbnail for a single artifact.
///
/// Uses [IdzApiClient.getArtifactBytes] (which sends the configured
/// `Authorization: Bearer …` header) and caches the bytes per session.
/// The widget itself is lazy — the fetch only fires when this is first
/// built, so wrapping it inside an offscreen `ListView` item gives you
/// "fetch when scrolled into view" for free.
class ArtifactThumb extends StatefulWidget {
  const ArtifactThumb({
    super.key,
    required this.client,
    required this.verificationId,
    required this.artifactId,
    this.size = 96,
    this.onTap,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final IdzApiClient client;
  final String verificationId;
  final String artifactId;
  final double size;
  final VoidCallback? onTap;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<ArtifactThumb> createState() => _ArtifactThumbState();
}

class _ArtifactThumbState extends State<ArtifactThumb> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ArtifactThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verificationId != widget.verificationId ||
        oldWidget.artifactId != widget.artifactId) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() async {
    final cached = _ArtifactBytesCache.get(
      widget.verificationId,
      widget.artifactId,
    );
    if (cached != null) return cached;
    final result = await widget.client.getArtifactBytes(
      widget.verificationId,
      widget.artifactId,
    );
    return result.fold<Uint8List?>((_) => null, (bytes) {
      final u8 = Uint8List.fromList(bytes.bytes);
      _ArtifactBytesCache.put(widget.verificationId, widget.artifactId, u8);
      return u8;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: FutureBuilder<Uint8List?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Container(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final bytes = snapshot.data;
                if (bytes == null || bytes.isEmpty) {
                  return Container(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    child: Icon(
                      Icons.broken_image,
                      color: scheme.onErrorContainer,
                    ),
                  );
                }
                return Image.memory(
                  bytes,
                  fit: widget.fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    child: Icon(
                      Icons.broken_image,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen viewer pushed when a thumbnail is tapped.
class ArtifactViewer extends StatelessWidget {
  const ArtifactViewer({
    super.key,
    required this.client,
    required this.verificationId,
    required this.artifactId,
    this.title,
  });

  final IdzApiClient client;
  final String verificationId;
  final String artifactId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!),
      ),
      body: InteractiveViewer(
        child: Center(
          child: ArtifactThumb(
            client: client,
            verificationId: verificationId,
            artifactId: artifactId,
            size: MediaQuery.of(context).size.shortestSide,
            borderRadius: 0,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
