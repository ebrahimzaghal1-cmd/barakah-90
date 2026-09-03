import 'package:flutter/material.dart';

class HomeStripCardStyle {
  const HomeStripCardStyle({
    required this.shape,
    required this.size,
  });

  final String shape;
  final String size;

  factory HomeStripCardStyle.fromMap(
    Map<String, dynamic> data, {
    String legacyShape = 'circle',
    String legacySize = 'medium',
  }) {
    final rawShape = data['cardShape']?.toString();
    final rawSize = data['cardSize']?.toString();

    return HomeStripCardStyle(
      shape: const {'circle', 'square', 'rectangle'}.contains(rawShape)
          ? rawShape!
          : legacyShape,
      size: const {'small', 'medium', 'large'}.contains(rawSize)
          ? rawSize!
          : legacySize,
    );
  }

  bool get isCircle => shape == 'circle';
  bool get isRectangle => shape == 'rectangle';

  double get height {
    switch (size) {
      case 'small':
        return 74;
      case 'large':
        return 116;
      default:
        return 94;
    }
  }

  double get width {
    final base = height;
    if (!isRectangle) return base;

    switch (size) {
      case 'small':
        return 104;
      case 'large':
        return 164;
      default:
        return 132;
    }
  }

  double get itemWidth => width + 16;

  double get stripHeight => height + 58;

  BorderRadius get borderRadius {
    if (isCircle) return BorderRadius.circular(999);
    if (shape == 'square') return BorderRadius.circular(18);
    return BorderRadius.circular(20);
  }

  Widget clip(Widget child) {
    if (isCircle) return ClipOval(child: child);
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}
