import 'package:flutter/material.dart';

/// Centers wide layouts while keeping phone screens comfortably padded.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxWidth, minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}
