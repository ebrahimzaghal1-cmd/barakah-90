import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A public OpenStreetMap humanitarian layer that does not require an API key.
///
/// It renders local Arabic place names where available, while Barakah's own
/// places are always displayed using the Arabic marker labels below.
TileLayer arabicMapTileLayer() => TileLayer(
      urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.barakah.market',
      maxNativeZoom: 19,
    );

class ArabicMapMarker extends StatelessWidget {
  const ArabicMapMarker({
    super.key,
    required this.label,
    this.icon = Icons.location_on_rounded,
    this.color = Colors.red,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.trim().isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 118),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withOpacity(.35)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF071B3C),
                ),
              ),
            ),
          Icon(icon, color: color, size: 42),
        ],
      );
}

class ArabicMapAttribution extends StatelessWidget {
  const ArabicMapAttribution({super.key});

  @override
  Widget build(BuildContext context) => const SimpleAttributionWidget(
        source: Text(
          '© مساهمو OpenStreetMap | نمط Humanitarian',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 9),
        ),
      );
}
