import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/chat_media_service.dart';
import '../services/chat_video_controller.dart';

class ChatMediaPicker extends StatelessWidget {
  const ChatMediaPicker({super.key, required this.draft, this.enabled = true});
  final ChatMediaDraft draft;
  final bool enabled;

  Future<void> _pick(BuildContext context, bool video) async {
    try {
      await draft.pick(isVideo: video);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: draft,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              PopupMenuButton<bool>(
                tooltip: 'إرفاق صورة أو فيديو',
                enabled: enabled && !draft.isBusy,
                icon: const Icon(Icons.attach_file_rounded),
                onSelected: (video) => _pick(context, video),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('صورة')),
                  PopupMenuItem(value: true, child: Text('فيديو')),
                ],
              ),
              Expanded(
                child: Text(
                  draft.isBusy
                      ? 'جارٍ تجهيز المرفق…'
                      : draft.hasAttachment
                          ? draft.file!.name
                          : 'صورة حتى 10 م.ب أو فيديو حتى 30 ثانية و50 م.ب',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (draft.isBusy)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (draft.hasAttachment)
                IconButton(
                  tooltip: 'إزالة المرفق',
                  onPressed: enabled && !draft.isBusy ? draft.clear : null,
                  icon: const Icon(Icons.close_rounded),
                ),
            ]),
            if (draft.hasAttachment)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 100,
                  width: 160,
                  child: draft.isVideo
                      ? _VideoAttachment(
                          key: ValueKey(draft.file!.path),
                          source: draft.file!.path,
                          local: true,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            draft.imageBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text('الصورة جاهزة للإرسال')),
                          ),
                        ),
                ),
              ),
          ],
        ),
      );
}

class ChatMessageContent extends StatelessWidget {
  const ChatMessageContent({super.key, required this.data, this.textStyle});
  final Map<String, dynamic> data;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final text = data['text']?.toString() ?? '';
    final image = data['imageUrl']?.toString().trim() ?? '';
    final video = data['videoUrl']?.toString().trim() ?? '';
    final validImage = isTrustedChatMediaUrl(image);
    final validVideo = isTrustedChatMediaUrl(video);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image.isNotEmpty || video.isNotEmpty) ...[
          if (validImage)
            Semantics(
              label: 'عرض الصورة',
              button: true,
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: Stack(children: [
                      InteractiveViewer(
                        child: Image.network(image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const _UnavailableMedia()),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ]),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    image,
                    width: 260,
                    height: 180,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => const _UnavailableMedia(),
                  ),
                ),
              ),
            )
          else if (validVideo)
            SizedBox(
              width: 260,
              height: 180,
              child: _VideoAttachment(key: ValueKey(video), source: video),
            )
          else
            const _UnavailableMedia(),
          if (text.isNotEmpty) const SizedBox(height: 8),
        ],
        if (text.isNotEmpty) Text(text, style: textStyle),
      ],
    );
  }
}

class _UnavailableMedia extends StatelessWidget {
  const _UnavailableMedia();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('تعذر عرض المرفق'),
      );
}

/// Remote videos load only when requested; scrolling a conversation never
/// starts a collection of downloads or simultaneous playback.
class _VideoAttachment extends StatefulWidget {
  const _VideoAttachment({super.key, required this.source, this.local = false});
  final String source;
  final bool local;
  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  Future<void> _play() async {
    if (_loading) return;
    final existing = _controller;
    if (existing != null && existing.value.isInitialized) {
      if (existing.value.isPlaying) {
        await existing.pause();
      } else {
        if (existing.value.position >= existing.value.duration) {
          await existing.seekTo(Duration.zero);
        }
        await existing.play();
      }
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = widget.local
        ? localChatVideoController(widget.source)
        : VideoPlayerController.networkUrl(Uri.parse(widget.source));
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await controller.play();
    } catch (_) {
      if (mounted) {
        _controller = null;
        await controller.dispose();
        if (mounted) setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.black87,
        child: controller != null && controller.value.isInitialized
            ? ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (_, value, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio:
                            value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    IconButton(
                      tooltip: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل الفيديو',
                      onPressed: _play,
                      color: Colors.white,
                      iconSize: 40,
                      icon: Icon(value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(controller,
                          allowScrubbing: true),
                    ),
                  ],
                ),
              )
            : Center(
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : TextButton.icon(
                        onPressed: _play,
                        icon: const Icon(Icons.play_circle_fill,
                            color: Colors.white),
                        label: Text(
                          _failed
                              ? 'تعذر التشغيل، أعد المحاولة'
                              : 'تشغيل الفيديو',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
              ),
      ),
    );
  }
}
