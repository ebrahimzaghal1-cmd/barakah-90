import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ترويسة موحّدة لأقسام بركة، مع اختلاف الصورة فقط بين كل قسم.
class BarakahSectionHeader extends StatelessWidget {
  const BarakahSectionHeader({
    super.key,
    required this.assetPath,
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final appWidth = MediaQuery.sizeOf(context).width;
    const headerAspectRatio = 1774 / 441;
    final headerHeight = ((appWidth - 4) / headerAspectRatio) + 4;

    return SizedBox(
      height: headerHeight,
      child: OverflowBox(
        minWidth: appWidth,
        maxWidth: appWidth,
        minHeight: headerHeight,
        maxHeight: headerHeight,
        alignment: Alignment.center,
        child: Container(
          width: appWidth,
          height: headerHeight,
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppTheme.coolYellow.withOpacity(.42),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Image.asset(
            assetPath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
