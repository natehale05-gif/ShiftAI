import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import '../../widgets/spinner.dart';

/// The piece itself in the vault's detail: the full image, a playable
/// video, or an audio player over the piece's art. A document, or anything
/// with no file, is its art.
///
/// Media URLs need no auth header (Rex's notes): they are public by an
/// unguessable name and served from the app's own origin, which is what
/// lets CanvasKit draw them on the web. Video is served with HTTP Range, so
/// seeking works and iOS Safari plays it.
class VaultMedia extends StatelessWidget {
  const VaultMedia({required this.item, super.key});

  final VaultItem item;

  @override
  Widget build(BuildContext context) {
    final String? file = item.mediaUrl;
    return switch (item.mediaType) {
      MediaType.video when file != null => _VideoView(item: item, url: file),
      MediaType.audio when file != null => _AudioView(item: item, url: file),
      // The full file for an image, the preview until it arrives.
      MediaType.image => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MediaArt(seed: item.id, thumbnailUrl: item.thumbnailUrl),
            if (file != null)
              Image.network(
                file,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder:
                    (BuildContext context, Object _, StackTrace? __) =>
                        const SizedBox.shrink(),
              ),
          ],
        ),
      _ => MediaArt(seed: item.id, thumbnailUrl: item.thumbnailUrl),
    };
  }
}

/// A video's poster until it is tapped; then the player. Nothing is
/// fetched until then, so opening the detail does not start a download.
class _VideoView extends StatefulWidget {
  const _VideoView({required this.item, required this.url});

  final VaultItem item;
  final String url;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _player;
  bool _failed = false;

  Future<void> _start() async {
    final VideoPlayerController player =
        VideoPlayerController.networkUrl(Uri.parse(widget.url));
    setState(() => _player = player);
    try {
      await player.initialize();
      if (!mounted) return;
      await player.play();
      setState(() {});
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final VideoPlayerController? player = _player;
    final bool ready = player != null && player.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (!ready)
          MediaArt(seed: widget.item.id, thumbnailUrl: widget.item.thumbnailUrl)
        else
          ColoredBox(
            color: MediaInk.scrim,
            child: Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
          ),
        if (_failed)
          Center(
            child: Container(
              padding: const EdgeInsets.all(Space.x3),
              decoration: BoxDecoration(
                color: MediaInk.scrim.withValues(alpha: 0.6),
                borderRadius: Radii.mdAll,
              ),
              child: Text(
                'This clip would not play.',
                style: ShiftType.copy(MediaInk.onMedia, size: 14, weight: 500),
              ),
            ),
          )
        else if (player == null)
          Center(
            child: Semantics(
              button: true,
              label: 'Play ${widget.item.title}',
              child: GestureDetector(
                onTap: _start,
                child: const PlayDisc(size: 56),
              ),
            ),
          )
        else if (!ready)
          const Center(
            child: ShiftSpinner(color: MediaInk.onMedia, size: 28),
          )
        else ...<Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                player.value.isPlaying ? player.pause() : player.play();
              }),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: player,
            builder: (BuildContext context, VideoPlayerValue v, _) =>
                v.isPlaying
                    ? const SizedBox.shrink()
                    : const Center(
                        child: IgnorePointer(child: PlayDisc(size: 56)),
                      ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              player,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 8),
              colors: VideoProgressColors(
                playedColor: c.accent,
                bufferedColor: MediaInk.onMedia.withValues(alpha: 0.35),
                backgroundColor: MediaInk.onMedia.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Audio over the piece's art: play or pause, how far along, and a bar to
/// move through it.
class _AudioView extends StatefulWidget {
  const _AudioView({required this.item, required this.url});

  final VaultItem item;
  final String url;

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  VideoPlayerController? _player;
  bool _failed = false;

  Future<void> _toggle() async {
    VideoPlayerController? player = _player;
    if (player == null) {
      player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      setState(() => _player = player);
      try {
        await player.initialize();
      } on Object {
        if (mounted) setState(() => _failed = true);
        return;
      }
    }
    player.value.isPlaying ? await player.pause() : await player.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final VideoPlayerController? player = _player;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MediaArt(seed: widget.item.id, thumbnailUrl: widget.item.thumbnailUrl),
        Positioned(
          left: Space.x3,
          right: Space.x3,
          bottom: Space.x3,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              Space.x1,
              Space.x1,
              Space.x4,
              Space.x1,
            ),
            decoration: BoxDecoration(
              color: MediaInk.scrim.withValues(alpha: 0.5),
              borderRadius: Radii.pillAll,
            ),
            child: player == null || !player.value.isInitialized
                ? Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Play',
                        onPressed: _failed ? null : _toggle,
                        icon: player == null || _failed
                            ? const Icon(
                                Icons.play_arrow_rounded,
                                color: MediaInk.onMedia,
                              )
                            : const ShiftSpinner(
                                color: MediaInk.onMedia, size: 18),
                      ),
                      Expanded(
                        child: Text(
                          _failed ? 'This would not play.' : widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShiftType.copy(
                            MediaInk.onMedia,
                            size: 14,
                            weight: 500,
                          ),
                        ),
                      ),
                    ],
                  )
                : ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: player,
                    builder: (BuildContext context, VideoPlayerValue v, _) {
                      final int total = v.duration.inMilliseconds;
                      return Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: v.isPlaying ? 'Pause' : 'Play',
                            onPressed: _toggle,
                            icon: Icon(
                              v.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: MediaInk.onMedia,
                            ),
                          ),
                          Text(
                            _clock(v.position),
                            style: ShiftType.figures(
                              MediaInk.onMedia,
                              size: 12,
                              weight: 500,
                            ),
                          ),
                          Expanded(
                            child: // Apple's own scrubber, the one in every iOS player, rather than
                                // a restyled Material slider.
                                CupertinoSlider(
                              activeColor: c.accent,
                              thumbColor: MediaInk.onMedia,
                              value: total == 0
                                  ? 0
                                  : (v.position.inMilliseconds / total)
                                      .clamp(0, 1)
                                      .toDouble(),
                              onChanged: total == 0
                                  ? null
                                  : (double f) => player.seekTo(
                                        Duration(
                                          milliseconds: (f * total).round(),
                                        ),
                                      ),
                            ),
                          ),
                          Text(
                            _clock(v.duration),
                            style: ShiftType.figures(
                              MediaInk.onMedia,
                              size: 12,
                              weight: 500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
