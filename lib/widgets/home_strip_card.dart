import 'package:flutter/material.dart';

import '../models/home_strip_card_style.dart';
import '../theme/app_theme.dart';

class HomeStripCard extends StatelessWidget {
  const HomeStripCard({
    super.key,
    required this.style,
    required this.title,
    required this.image,
    required this.onTap,
    this.heroTag,
  });

  final HomeStripCardStyle style;
  final String title;
  final Widget image;
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(style.cornerRadius);
    Widget imageFrame = Container(
      width: style.imageWidth,
      height: style.imageHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: style.isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: style.isCircle ? null : radius,
        border: Border.all(color: AppTheme.deepYellow, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26071B3C),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, .20, .48, .78, 1],
                    colors: [
                      Colors.white.withOpacity(.34),
                      Colors.white.withOpacity(.10),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withOpacity(.06),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (heroTag != null) {
      imageFrame = Hero(tag: heroTag!, child: imageFrame);
    }

    return SizedBox(
      width: style.tileWidth,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageFrame,
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: style.size == HomeStripCardSize.large ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: switch (style.size) {
                  HomeStripCardSize.small => 11,
                  HomeStripCardSize.medium => 13,
                  HomeStripCardSize.large => 14,
                },
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
