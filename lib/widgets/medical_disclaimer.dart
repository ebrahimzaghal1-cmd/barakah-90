import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key, this.compact = false});

  final bool compact;

  static const text =
      'تنبيه طبي: بركة منصة للحجز والتواصل وليست جهازًا طبيًا، ولا تقدّم '
      'تشخيصًا أو علاجًا ولا تستبدل استشارة الطبيب. في الحالات الطارئة تواصل '
      'فورًا مع خدمات الطوارئ المحلية.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.deepYellow.withOpacity(.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.navy,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: compact ? 12.5 : 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
