import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/firebase_state.dart';
import '../theme/app_theme.dart';
import 'barakah_brand.dart';

class AdvertisementBanner extends StatelessWidget {
  const AdvertisementBanner({super.key, required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (context, snapshot) {
        final ads = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          final target = data['placement']?.toString() ?? 'all';
          return data['isActive'] != false &&
              (target == 'all' || target == placement);
        }).toList();
        if (ads.isEmpty) return const SizedBox.shrink();
        ads.sort((a, b) {
          final right =
              (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  0;
          final left =
              (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  0;
          return right.compareTo(left);
        });
        return _AdCarousel(ads: ads.take(7).toList());
      },
    );
  }
}

/// إعلانات ممولة تظهر بين أقسام التصفح بصورة رئيسية ومعرض صور مصغّرة.
class SponsoredAdsFeed extends StatelessWidget {
  const SponsoredAdsFeed({super.key, required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (context, snapshot) {
        final ads = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          final target = data['placement']?.toString() ?? 'all';
          final image = data['image']?.toString() ?? '';
          final gallery = data['gallery'] as List?;
          return data['isActive'] != false &&
              data['showInFeed'] != false &&
              (target == 'all' || target == placement) &&
              (image.isNotEmpty || gallery?.isNotEmpty == true);
        }).toList()
          ..sort((a, b) {
            final right =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final left =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return right.compareTo(left);
          });
        if (ads.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text('إعلانات ممولة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            ...ads.take(2).map((ad) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: _SponsoredGalleryCard(data: ad.data()),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _SponsoredGalleryCard extends StatefulWidget {
  const _SponsoredGalleryCard({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_SponsoredGalleryCard> createState() => _SponsoredGalleryCardState();
}

class _SponsoredGalleryCardState extends State<_SponsoredGalleryCard> {
  int _selected = 0;

  List<String> get _images {
    final main = widget.data['image']?.toString() ?? '';
    final gallery = (widget.data['gallery'] as List?)
            ?.map((item) => item.toString())
            .where((url) => url.isNotEmpty) ??
        const Iterable<String>.empty();
    return <String>{if (main.isNotEmpty) main, ...gallery}.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.isEmpty) return const SizedBox.shrink();
    if (_selected >= images.length) _selected = 0;
    final title = widget.data['title']?.toString() ?? 'إعلان بركة';
    final subtitle = widget.data['subtitle']?.toString() ?? '';
    final displaySize = widget.data['displaySize']?.toString() ?? 'large';
    final imageAspectRatio = switch (displaySize) {
      'small' => 2.8,
      'medium' => 1.8,
      _ => 1.35,
    };
    final outerPadding = displaySize == 'small' ? 8.0 : 12.0;
    final titleSize = displaySize == 'small'
        ? 15.0
        : displaySize == 'medium'
            ? 17.0
            : 18.0;
    final thumbnailHeight = displaySize == 'small'
        ? 52.0
        : displaySize == 'medium'
            ? 64.0
            : 76.0;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white.withOpacity(.86),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(outerPadding),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.coolYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ممول',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: titleSize, fontWeight: FontWeight.w900)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                width: 116,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const BarakahBrandName(light: true, compact: true),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: imageAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(
                      images[_selected],
                      key: ValueKey(images[_selected]),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.ink,
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white, size: 44),
                      ),
                    ),
                    if (images.length > 1)
                      PositionedDirectional(
                        start: 12,
                        end: 12,
                        bottom: 12,
                        child: Container(
                          height: thumbnailHeight,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, index) => GestureDetector(
                              onTap: () => setState(() => _selected = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: index == _selected ? 88 : 66,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: index == _selected
                                        ? AppTheme.coolYellow
                                        : Colors.white70,
                                    width: index == _selected ? 3 : 1,
                                  ),
                                ),
                                child: Image.network(images[index],
                                    fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// إعلان متحرك: حتى سبع صور أو فيديوهات في الصفحة الرئيسية.
class _AdCarousel extends StatefulWidget {
  const _AdCarousel({required this.ads});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> ads;

  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.ads.length) _page = 0;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.ads.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.ads.length;
      _controller.animateToPage(_page,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizes = widget.ads
        .map((ad) => ad.data()['displaySize']?.toString() ?? 'large')
        .toList();

    final currentSize =
        sizes.isEmpty ? 'large' : sizes[_page.clamp(0, sizes.length - 1)];

    final height = switch (currentSize) {
      'small' => 155.0,
      'medium' => 215.0,
      _ => 295.0,
    };
    final appWidth = MediaQuery.sizeOf(context).width;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: height,
      child: OverflowBox(
        minWidth: appWidth,
        maxWidth: appWidth,
        minHeight: height,
        maxHeight: height,
        alignment: Alignment.center,
        child: SizedBox(
          width: appWidth,
          height: height,
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.ads.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) =>
                    _AdCard(data: widget.ads[index].data()),
              ),
            ),
            if (widget.ads.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      widget.ads.length,
                      (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? AppTheme.deepYellow
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _AdCard extends StatefulWidget {
  const _AdCard({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<_AdCard> {
  VideoPlayerController? _controller;
  Timer? _imageTimer;
  int _imagePage = 0;
  bool _failed = false;

  List<String> get _images {
    final main = widget.data['image']?.toString().trim() ?? '';
    final gallery = (widget.data['gallery'] as List?)
            ?.map((item) => item.toString().trim())
            .where((url) => url.isNotEmpty) ??
        const Iterable<String>.empty();
    return <String>{if (main.isNotEmpty) main, ...gallery}.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _startImageTimer();
    final video = widget.data['video']?.toString() ?? '';
    if (video.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(video))
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!
            ..setLooping(true)
            ..play();
          setState(() {});
        }).catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    }
  }

  void _startImageTimer() {
    _imageTimer?.cancel();
    if (_images.length < 2 ||
        (widget.data['video']?.toString() ?? '').isNotEmpty) {
      return;
    }
    _imageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _imagePage = (_imagePage + 1) % _images.length);
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? 'إعلان بركة';
    final subtitle = widget.data['subtitle']?.toString() ?? '';
    final images = _images;
    if (_imagePage >= images.length) _imagePage = 0;
    final playable = _controller?.value.isInitialized == true && !_failed;
    return Container(
      height: 184,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.zero,
        color: AppTheme.ink,
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (playable)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (images.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Image.network(
              images[_imagePage],
              key: ValueKey(images[_imagePage]),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppTheme.ink,
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white, size: 42),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.black.withOpacity(.68),
              Colors.black.withOpacity(.08),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_controller != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.25),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('فيديو تسويقي',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: Colors.white)),
              ]),
        ),
        PositionedDirectional(
          top: 10,
          end: 10,
          child: Container(
            width: 126,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.navy.withOpacity(.90),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withOpacity(.25)),
            ),
            child: const BarakahBrandName(light: true, compact: true),
          ),
        ),
        if (playable)
          Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              onPressed: () => setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              }),
              icon: Icon(_controller!.value.isPlaying
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
              color: Colors.white,
              iconSize: 32,
            ),
          ),
        if (!playable && images.length > 1)
          PositionedDirectional(
            top: 18,
            start: 14,
            child: Row(
              children: List.generate(
                images.length,
                (index) => GestureDetector(
                  onTap: () => setState(() => _imagePage = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _imagePage ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(
                      color: index == _imagePage
                          ? AppTheme.coolYellow
                          : Colors.white70,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
