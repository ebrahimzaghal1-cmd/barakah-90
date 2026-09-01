import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/business_hours_service.dart';
import '../theme/app_theme.dart';
import 'business_rating.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final dynamic restaurant;

  @override
  Widget build(BuildContext context) {
    // عناصر Firestore القديمة قد لا تحتوي كل الحقول الجديدة مثل السعر.
    // نحول الـ DocumentSnapshot إلى خريطة قبل القراءة حتى لا يتعطل الكرت.
    final data = restaurant is Map<String, dynamic>
        ? restaurant as Map<String, dynamic>
        : restaurant.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final name = data['title']?.toString() ?? 'بدون اسم';
    final image = data['image']?.toString() ?? '';
    final imageShape = data['imageShape']?.toString() ?? 'rounded';
    final price = data['price'];
    final rating = data['rating'];
    final businessId =
        restaurant is DocumentSnapshot ? restaurant.id : data['id']?.toString();
    final isProduct = data['kind']?.toString() == 'product';
    final discount = (data['discountPercent'] as num?)?.toDouble() ?? 0;
    final deliveryFee = data['deliveryFee'];
    final category = data['category']?.toString() ?? 'بركة';
    final deliveryTime = data['deliveryTime']?.toString().trim() ??
        data['estimatedDeliveryTime']?.toString().trim() ??
        '25–35 د';
    final distance = data['distanceKm'] ?? data['distance'];
    final hoursStatus =
        isProduct ? null : BusinessHoursService.resolve(data: data);

    return Material(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.coolYellow.withOpacity(.48)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            image.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFFFF1B8),
                    child: Icon(Icons.image_outlined, size: 46))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(
                      imageShape == 'square' ? 0 : 20,
                    ),
                    child: Image.network(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFFFF1B8),
                            child: Icon(Icons.broken_image_outlined, size: 46))),
                  ),
            const Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xD90B1B31),
                    child: Icon(Icons.favorite_border,
                        size: 18, color: Color(0xFFE8C64A)))),
            if (!isProduct && discount > 0)
              Positioned(
                top: 8,
                left: 8,
                child: _OfferChip(
                  text:
                      'خصم حتى ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}٪',
                  icon: Icons.percent_rounded,
                ),
              ),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hoursStatus != null)
                      _RestaurantStatusBadge(status: hoursStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isProduct)
                      Expanded(
                        child: Text(
                          price == null ? 'السعر عند الطلب' : '$price ₪',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.deepYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else if (businessId != null)
                      Flexible(
                        child: BusinessRating(
                          businessId: businessId,
                          fallbackRating: rating,
                          compact: true,
                          foregroundColor: AppTheme.ink,
                        ),
                      )
                    else ...[
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFB800), size: 14),
                      Text(
                        rating?.toString() ?? 'جديد',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (!isProduct) ...[
                      const Spacer(),
                      const Icon(Icons.schedule_rounded,
                          color: AppTheme.deepYellow, size: 12),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          deliveryTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded,
                            color: AppTheme.deepYellow, size: 11),
                        Text(
                          '$distance كم',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                if (!isProduct) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF12345B), Color(0xFF071B3C)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFFD7A928).withOpacity(.55),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      deliveryFee == null || deliveryFee == 0
                          ? 'توصيل مجاني'
                          : 'توصيل $deliveryFee شيكل',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        ]),
      ),
    );
  }
}

class _RestaurantStatusBadge extends StatelessWidget {
  const _RestaurantStatusBadge({required this.status});

  final BusinessHoursStatus status;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final IconData icon;

    switch (status.code) {
      case 'open':
        background = const Color(0xFFE8F8EF);
        foreground = const Color(0xFF167A45);
        icon = Icons.check_circle_rounded;
        break;

      case 'closing_soon':
        background = const Color(0xFFFFF1D6);
        foreground = const Color(0xFF9B6200);
        icon = Icons.schedule_rounded;
        break;

      case 'opening_soon':
        background = const Color(0xFFFFF7CC);
        foreground = const Color(0xFF806400);
        icon = Icons.schedule_rounded;
        break;

      case 'busy':
        background = const Color(0xFFFFE8D9);
        foreground = const Color(0xFFA74600);
        icon = Icons.local_fire_department_rounded;
        break;

      case 'temporarily_closed':
        background = const Color(0xFFFFE5E5);
        foreground = const Color(0xFFA52626);
        icon = Icons.pause_circle_filled_rounded;
        break;

      default:
        background = const Color(0xFFF0F1F3);
        foreground = const Color(0xFF646B75);
        icon = Icons.lock_clock_rounded;
    }

    var text = status.label;

    if (status.minutesUntilChange != null &&
        (status.code == 'closing_soon' || status.code == 'opening_soon')) {
      text = '$text • ${status.minutesUntilChange} د';
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: foreground,
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF172B4D).withOpacity(.92),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFFFFE65B), size: 13),
          const SizedBox(width: 3),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ]),
      );
}
