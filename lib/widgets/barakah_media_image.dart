import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

bool isInlineBarakahImage(String path) => path.startsWith('data:image/');

Uint8List? decodeInlineBarakahImage(String path) {
  if (!isInlineBarakahImage(path)) return null;
  final separator = path.indexOf(',');
  if (separator < 0 || separator == path.length - 1) return null;
  try {
    return base64Decode(path.substring(separator + 1));
  } catch (_) {
    return null;
  }
}

ImageProvider<Object>? barakahImageProvider(String path) {
  final inline = decodeInlineBarakahImage(path);
  if (inline != null) return MemoryImage(inline);
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.isNotEmpty) return AssetImage(path);
  return null;
}

class BarakahMediaImage extends StatelessWidget {
  const BarakahMediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final fallbackWidget = fallback ??
        const ColoredBox(
          color: Color(0xFFF4D76B),
          child: Center(child: Icon(Icons.image_not_supported_outlined)),
        );
    final inline = decodeInlineBarakahImage(path);
    if (inline != null) {
      return Image.memory(
        inline,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackWidget,
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackWidget,
      );
    }
    if (path.isNotEmpty) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackWidget,
      );
    }
    return SizedBox(width: width, height: height, child: fallbackWidget);
  }
}
