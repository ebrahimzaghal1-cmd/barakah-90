import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/rating_service.dart';

class BusinessRating extends StatelessWidget {
  const BusinessRating({
    super.key,
    required this.businessId,
    this.fallbackRating,
    this.compact = false,
    this.foregroundColor,
  });

  final String businessId;
  final Object? fallbackRating;
  final bool compact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: RatingService().summaryFor(businessId),
        builder: (context, snapshot) {
          final summary = RatingSummary.fromData(snapshot.data?.data());
          final fallback = (fallbackRating as num?)?.toDouble() ?? 0;
          final average = summary.count == 0 ? fallback : summary.average;
          final ratingRow = Row(mainAxisSize: MainAxisSize.min, children: [
            ...List.generate(
              5,
              (index) => Icon(
                average >= index + 1
                    ? Icons.star_rounded
                    : average >= index + .5
                        ? Icons.star_half_rounded
                        : Icons.star_border_rounded,
                color: const Color(0xFFFFB800),
                size: compact ? 14 : 21,
              ),
            ),
            const SizedBox(width: 4),
            Text(average == 0 ? 'جديد' : average.toStringAsFixed(1),
                style: TextStyle(
                    color: foregroundColor,
                    fontSize: compact ? 10 : 13,
                    fontWeight: FontWeight.w900)),
            if (!compact && summary.count > 0)
              Text(' (${summary.count})',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]);

          if (!compact) return ratingRow;

          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: ratingRow,
          );
        },
      );
}

class RateBusinessButton extends StatelessWidget {
  const RateBusinessButton(
      {super.key, required this.businessId, required this.businessName});
  final String businessId;
  final String businessName;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.star_rate_rounded),
        label: const Text('قيّم المحل أو المطعم'),
        onPressed: () async {
          final selected = await showModalBottomSheet<int>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('ما تقييمك لـ $businessName؟',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        tooltip: '${index + 1} من 5',
                        iconSize: 42,
                        color: const Color(0xFFFFB800),
                        icon: const Icon(Icons.star_rounded),
                        onPressed: () => Navigator.pop(sheetContext, index + 1),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
          if (selected == null || !context.mounted) return;
          try {
            await RatingService().rateBusiness(businessId, selected);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('شكرًا، تم حفظ تقييمك بنجاح.')));
            }
          } catch (error) {
            if (context.mounted) {
              final message = error
                  .toString()
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Exception: ', '');
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            }
          }
        },
      );
}
