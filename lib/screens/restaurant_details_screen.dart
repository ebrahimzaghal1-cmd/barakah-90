import 'mediator_orders_screen.dart';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import '../widgets/business_rating.dart';
import '../widgets/favorite_button.dart';
import '../widgets/barber_booking_section.dart';
import 'product_details_screen.dart';
import 'customer_support_chat_screen.dart';

class RestaurantDetailsScreen extends StatelessWidget {
  const RestaurantDetailsScreen({super.key, required this.restaurant});

  final dynamic restaurant;

  Map<String, dynamic> get _data => restaurant is Map<String, dynamic>
      ? restaurant as Map<String, dynamic>
      : restaurant.data() as Map<String, dynamic>? ?? <String, dynamic>{};

  String? get _businessId => restaurant is DocumentSnapshot
      ? (restaurant as DocumentSnapshot).id
      : _data['id']?.toString();

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final name = data['title']?.toString() ?? 'التفاصيل';
    final image = data['image']?.toString() ?? '';
    final description = data['description']?.toString().trim();
    final category = data['category']?.toString() ?? 'بركة';
    final rating = data['rating'];
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    final isAgent = data['kind']?.toString() == 'agent';
    final typeValue = data['type']?.toString().toLowerCase().trim() ?? '';
    final merchantType =
        data['merchantType']?.toString().toLowerCase().trim() ?? '';
    final categoryValue =
        data['category']?.toString().toLowerCase().trim() ?? '';
    final activityValue =
        data['activityType']?.toString().toLowerCase().trim() ?? '';
    final isBarber = typeValue == 'barber' ||
        merchantType == 'barber' ||
        categoryValue.contains('حلاق') ||
        categoryValue.contains('barber') ||
        activityValue.contains('حلاق') ||
        activityValue.contains('barber');
    final agentLocation = data['agentLocation']?.toString().trim() ?? '';
    final merchantId = data['ownerId']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 370,
              pinned: true,
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background:
                    _GlassCover(image: image, title: name, category: category),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 27, fontWeight: FontWeight.w900)),
                      ),
                      if (_businessId != null)
                        BusinessRating(
                          businessId: _businessId!,
                          fallbackRating: rating,
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(category,
                        style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : 'لا يوجد وصف متوفر حالياً.',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        height: 1.65,
                      ),
                    ),
                    if (isAgent && _businessId != null) ...[
                      const SizedBox(height: 22),
                      const Text('بيانات الوسيط أو الوسيطة',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      FilledButton.icon(
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('طلب وسيطة من داخل بركة'),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => MediatorOrderForm(
                                    businessId: _businessId!, business: data))),
                      ),
                      if (agentLocation.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(agentLocation),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text('QR الصفحة'),
                            onPressed: () =>
                                _showAgentQr(context, _businessId!, name),
                          ),
                        ],
                      ),
                    ],
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('الاتجاهات إلى المكان'),
                          onPressed: () async {
                            final mapUrl = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&hl=ar&destination=$latitude,$longitude');
                            if (!await launchUrl(mapUrl,
                                    mode: LaunchMode.externalApplication) &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('تعذر فتح تطبيق الخرائط.')));
                            }
                          },
                        ),
                      ),
                    ],
                    if (_businessId != null) ...[
                      const SizedBox(height: 18),
                      if (merchantId.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: Text('مراسلة $name'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerSupportChatScreen(
                                  businessId: _businessId!,
                                  businessTitle: name,
                                  merchantId: merchantId,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: RateBusinessButton(
                          businessId: _businessId!,
                          businessName: name,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (isBarber) ...[
                        const Text(
                          'منتجات المحل',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BusinessProducts(
                            businessId: _businessId!, horizontal: true),
                        const SizedBox(height: 28),
                        BarberBookingSection(
                          businessId: _businessId!,
                          business: data,
                        ),
                      ] else ...[
                        const Text(
                          'المنتجات والأسعار',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BusinessProducts(businessId: _businessId!),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAgentQr(
      BuildContext context, String agentId, String name) async {
    final page = 'https://barakah-new.web.app/?agentItem=$agentId';
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('صفحة $name',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            QrImageView(data: page, size: 210),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة الصفحة'),
              onPressed: () => Share.share(page),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BusinessProducts extends StatelessWidget {
  const _BusinessProducts({required this.businessId, this.horizontal = false});
  final String businessId;
  final bool horizontal;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator());
          }
          final products = (snapshot.data?.docs ?? [])
              .where((item) =>
                  item.data()['kind']?.toString() == 'product' &&
                  item.data()['businessId']?.toString() == businessId)
              .toList();
          if (products.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'لا توجد أصناف مضافة لهذا المحل حالياً.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          final cards = products.map((product) {
            final data = product.data();
            final image = data['image']?.toString() ?? '';
            final title = data['title']?.toString() ?? 'منتج';
            final description = data['description']?.toString() ?? '';
            final price = data['price'] ?? 0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(
                    productId: product.id,
                    product: data,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.82),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: AppTheme.coolYellow.withOpacity(.6))),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: image.isEmpty
                          ? const ColoredBox(
                              color: AppTheme.coolYellow,
                              child: Icon(Icons.fastfood_rounded))
                          : Image.network(image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: AppTheme.coolYellow,
                                  child: Icon(Icons.broken_image_outlined))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          if (description.isNotEmpty)
                            Text(description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 5),
                          Text('$price ₪',
                              style: const TextStyle(
                                  color: AppTheme.deepYellow,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          BusinessRating(
                            businessId: product.id,
                            fallbackRating: data['rating'],
                            compact: true,
                          ),
                        ]),
                  ),
                  IconButton(
                    tooltip: 'قيّم الصنف',
                    color: const Color(0xFFFFB800),
                    icon: const Icon(Icons.star_rate_rounded),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: RateBusinessButton(
                            businessId: product.id,
                            businessName: title,
                          ),
                        ),
                      ),
                    ),
                  ),
                  FavoriteButton(
                    itemId: product.id,
                    item: data,
                    backgroundColor: AppTheme.navy,
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: AppTheme.deepYellow,
                        foregroundColor: Colors.white),
                    tooltip: 'أضف للسلة',
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(
                                productId: product.id, product: data))),
                  ),
                ]),
              ),
            );
          }).toList();
          if (horizontal) {
            return SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) =>
                    SizedBox(width: 330, child: cards[index]),
              ),
            );
          }
          return Column(children: cards);
        },
      );
}

class _GlassCover extends StatelessWidget {
  const _GlassCover({
    required this.image,
    required this.title,
    required this.category,
  });

  final String image;
  final String title;
  final String category;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        image.isEmpty
            ? const ColoredBox(
                color: AppTheme.coolYellow,
                child:
                    Icon(Icons.image_outlined, size: 96, color: AppTheme.ink))
            : image.startsWith('assets/')
                ? Image.asset(image, fit: BoxFit.cover)
                : Image.network(image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.coolYellow,
                        child: Icon(Icons.broken_image_outlined,
                            size: 96, color: AppTheme.ink))),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(.08),
                Colors.black.withOpacity(.62)
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.24),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(.55)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(category,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]);
}
