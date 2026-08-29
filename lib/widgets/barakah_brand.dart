import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// خلفية هوية بركة التقنية: كحلي وذهبي مثل لوحة الأدمن، مع انتقال زجاجي
/// مدروس في منطقة المحتوى حتى تبقى النصوص والبطاقات واضحة.
class BarakahBrandBackdrop extends StatelessWidget {
  const BarakahBrandBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x18FFFFFF),
                Color(0x10F4D77B),
                Color(0x08FFFFFF),
                Color(0x14D7A928),
              ],
              stops: [0.0, .35, .72, 1.0],
            ),
          ),
        ),

        // Pearl highlight.
        PositionedDirectional(
          top: -120,
          end: -110,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.70),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30E8C64A),
                    blurRadius: 100,
                    spreadRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Very light warm reflection.
        PositionedDirectional(
          start: -150,
          bottom: -150,
          child: IgnorePointer(
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF8DF).withOpacity(.30),
              ),
            ),
          ),
        ),

        child,
      ],
    );
  }
}

/// الاسم الرسمي للعلامة بخط ثقيل وواضح.
class BarakahBrandName extends StatelessWidget {
  const BarakahBrandName(
      {super.key,
      this.light = false,
      this.compact = false,
      this.foregroundColor});
  final bool light;
  final bool compact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? (light ? Colors.white : Colors.black);
    final shadow = light
        ? const [
            Shadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
          ]
        : null;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('بركة',
            style: TextStyle(
                color: color,
                fontSize: compact ? 31 : 43,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                shadows: shadow)),
        Container(
          width: 2,
          height: compact ? 30 : 42,
          margin: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          color: color.withOpacity(.72),
        ),
        Text('BARAKAH',
            textDirection: TextDirection.ltr,
            style: TextStyle(
                color: color,
                fontSize: compact ? 18 : 26,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? .4 : .8,
                shadows: shadow)),
      ]),
    );
  }
}
