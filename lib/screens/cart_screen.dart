import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/business_hours_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../config/app_features.dart';
import '../widgets/barakah_brand.dart';
import 'authentication_screen.dart';
import 'restaurants_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'سلتي',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: BarakahBrandBackdrop(
          child: AnimatedBuilder(
            animation: CartService.instance,
            builder: (context, _) {
              final cart = CartService.instance;

              if (cart.items.isEmpty) {
                return const _EmptyCart();
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _CartLineTile(
                        item: cart.items[index],
                        onAdd: () => cart.increment(cart.items[index]),
                        onRemove: () => cart.decrement(cart.items[index]),
                      ),
                    ),
                  ),
                  _CheckoutBar(
                    total: cart.total,
                    onCheckout: () => _showCheckout(context),
                  ),
                ],
              );
            },
          ),
        ),
      );

  Future<void> _showCheckout(BuildContext context) async {
    final cart = CartService.instance;
    final businessIds = cart.items
        .map((item) => item.businessId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (cart.items.any((item) => item.businessId.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يوجد صنف غير مرتبط بمحل. احذفه وأضفه مجددًا.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (businessIds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تكون أصناف الطلب من محل واحد فقط.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthenticationScreen(),
        ),
      );
      if (!context.mounted) return;
      if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سجّل الدخول أولًا لإتمام الطلب.'),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CheckoutSheet(),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 90),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _EmptyCartArtwork(),
              const SizedBox(height: 12),
              const Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'بركة',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 10),
                    SizedBox(
                      width: 2,
                      height: 27,
                      child: ColoredBox(
                        color: AppTheme.coolYellow,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'BARAKAH',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'سلتك فارغة',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'أضيفي أصنافك من أي مطعم أو محل لتظهر هنا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coolYellow,
                    foregroundColor: AppTheme.navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestaurantsScreen(),
                    ),
                  ),
                  child: const Text(
                    'تصفّح بركة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.onAdd,
    required this.onRemove,
  });

  final CartLine item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.coolYellow.withOpacity(.42),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 68,
                width: 68,
                child: item.image.isEmpty
                    ? const ColoredBox(
                        color: AppTheme.coolYellow,
                        child: Icon(Icons.fastfood_rounded),
                      )
                    : Image.network(
                        item.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AppTheme.coolYellow,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (item.businessTitle.isNotEmpty)
                    Text(
                      item.businessTitle,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.lineTotal} ₪',
                    style: const TextStyle(
                      color: AppTheme.coolYellow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _QuantityControl(
              quantity: item.quantity,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
          ],
        ),
      );
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.black54,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppTheme.coolYellow,
            ),
          ),
        ],
      );
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.onCheckout,
  });

  final num total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xEFFFFFFF),
            border: Border(
              top: BorderSide(
                color: AppTheme.coolYellow.withOpacity(.40),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'المجموع',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$total ₪',
                    style: const TextStyle(
                      color: AppTheme.coolYellow,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coolYellow,
                    foregroundColor: AppTheme.navy,
                  ),
                  onPressed: onCheckout,
                  icon: const Icon(
                    Icons.shopping_bag_rounded,
                  ),
                  label: const Text(
                    'إتمام الطلب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet();

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _delivery = 'delivery';
  String _payment = 'cash';
  bool _saving = false;
  DateTime? _scheduledFor;
  num _deliveryFee = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeCoupons = const [];
  String? _selectedCouponId;
  double? _deliveryDistanceKm;
  bool _deliveryOutsideRange = false;

  bool _useBarakahPoints = false;
  int _loyaltyPoints = 0;
  int _redemptionPoints = 1000;
  num _redemptionValue = 10;
  int _selectedBarakahPoints = 0;
  final TextEditingController _barakahPin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  @override
  void dispose() {
    _barakahPin.dispose();
    super.dispose();
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double radians(double value) => value * math.pi / 180;

    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return 6371 *
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );
  }

  Future<void> _loadCheckoutData() async {
    final cart = CartService.instance;

    try {
      Map<String, dynamic>? businessData;

      if (cart.items.isNotEmpty) {
        final business = await FirebaseFirestore.instance
            .collection('items')
            .doc(cart.items.first.businessId)
            .get();

        businessData = business.data();

        _deliveryFee = (businessData?['deliveryFee'] as num?) ?? 0;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        final userSnapshot =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        final userData = userSnapshot.data();

        _loyaltyPoints = (userData?['loyaltyPoints'] as num?)?.toInt() ?? 0;

        final couponSnapshot = await FirebaseFirestore.instance
            .collection('coupons')
            .where('customerId', isEqualTo: uid)
            .get();

        final now = DateTime.now();

        _activeCoupons = couponSnapshot.docs.where((doc) {
          final data = doc.data();

          if (data['status'] != 'active') return false;

          final expiresAt = data['expiresAt'];

          if (expiresAt is Timestamp) {
            return expiresAt.toDate().isAfter(now);
          }

          return true;
        }).toList();

        final customerLatitude =
            (userData?['agentLatitude'] as num?)?.toDouble();

        final customerLongitude =
            (userData?['agentLongitude'] as num?)?.toDouble();

        final businessLatitude =
            (businessData?['latitude'] as num?)?.toDouble();

        final businessLongitude =
            (businessData?['longitude'] as num?)?.toDouble();

        final rawDeliveryZones = businessData?['deliveryZones'];

        if (customerLatitude != null &&
            customerLongitude != null &&
            businessLatitude != null &&
            businessLongitude != null &&
            rawDeliveryZones is List &&
            rawDeliveryZones.isNotEmpty) {
          final zones = rawDeliveryZones
              .whereType<Map>()
              .map(
                (zone) => Map<String, dynamic>.from(zone),
              )
              .where(
                (zone) => zone['maxKm'] is num && zone['fee'] is num,
              )
              .toList()
            ..sort(
              (a, b) => (a['maxKm'] as num).compareTo(b['maxKm'] as num),
            );

          final distance = _distanceKm(
            businessLatitude,
            businessLongitude,
            customerLatitude,
            customerLongitude,
          );

          _deliveryDistanceKm = distance;

          Map<String, dynamic>? matchedZone;

          for (final zone in zones) {
            final maxKm = (zone['maxKm'] as num).toDouble();

            if (distance <= maxKm) {
              matchedZone = zone;
              break;
            }
          }

          if (matchedZone == null) {
            _deliveryFee = 0;
            _deliveryOutsideRange = true;
          } else {
            _deliveryFee = (matchedZone['fee'] as num?) ?? 0;
            _deliveryOutsideRange = false;
          }
        } else {
          _deliveryDistanceKm = null;
          _deliveryOutsideRange = false;

          _deliveryFee = (businessData?['deliveryFee'] as num?) ?? 0;
        }

        final settingsSnapshot = await FirebaseFirestore.instance
            .collection('app_settings')
            .doc('loyalty')
            .get();

        final settings = settingsSnapshot.data();

        final redeemPoints =
            (settings?['redemptionPoints'] as num?)?.toInt() ?? 1000;

        final redeemValue = (settings?['redemptionValue'] as num?) ?? 10;

        _redemptionPoints = redeemPoints <= 0 ? 1000 : redeemPoints;

        _redemptionValue = redeemValue <= 0 ? 10 : redeemValue;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // The secure server recalculates prices and delivery fees at submission.
    }
  }

  num get _estimatedOrderTotal {
    final cart = CartService.instance;
    final fee = _delivery == 'delivery' ? _deliveryFee : 0;
    return cart.total + fee;
  }

  int get _maxRedeemablePoints {
    if (_redemptionPoints <= 0 || _redemptionValue <= 0) {
      return 0;
    }

    final byBalance = (_loyaltyPoints ~/ _redemptionPoints) * _redemptionPoints;

    final maxChunksByTotal = (_estimatedOrderTotal / _redemptionValue).floor();

    final byTotal = maxChunksByTotal * _redemptionPoints;

    return byBalance < byTotal ? byBalance : byTotal;
  }

  num get _selectedPointsDiscount {
    if (_selectedBarakahPoints <= 0 || _redemptionPoints <= 0) {
      return 0;
    }

    return (_selectedBarakahPoints / _redemptionPoints) * _redemptionValue;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? get _selectedCoupon {
    final id = _selectedCouponId;
    if (id == null) return null;

    for (final coupon in _activeCoupons) {
      if (coupon.id == id) return coupon;
    }

    return null;
  }

  num get _selectedCouponDiscount {
    final coupon = _selectedCoupon;
    if (coupon == null) return 0;

    final percent = (coupon.data()['discountPercent'] as num?) ?? 0;
    if (percent <= 0) return 0;

    final discount = CartService.instance.total * percent / 100;

    return discount > CartService.instance.total
        ? CartService.instance.total
        : discount;
  }

  num get _estimatedPayableTotal {
    final value = _estimatedOrderTotal -
        _selectedPointsDiscount -
        _selectedCouponDiscount;

    return value < 0 ? 0 : value;
  }

  Future<void> _ensureBarakahIsAcceptingOrders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('app_hours')
        .get();

    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final closedMessage = data['closedMessage']?.toString().trim();

    if (data['temporarilyClosed'] == true) {
      throw StateError(
        closedMessage?.isNotEmpty == true
            ? closedMessage!
            : 'بركة مغلق مؤقتًا ولا يستقبل طلبات الآن.',
      );
    }

    final openingTime = data['openingTime']?.toString().trim() ?? '10:00';
    final closingTime = data['closingTime']?.toString().trim() ?? '03:00';

    final openParts = openingTime.split(':');
    final closeParts = closingTime.split(':');

    if (openParts.length != 2 || closeParts.length != 2) return;

    final openHour = int.tryParse(openParts[0]);
    final openMinute = int.tryParse(openParts[1]);
    final closeHour = int.tryParse(closeParts[0]);
    final closeMinute = int.tryParse(closeParts[1]);

    if (openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null) {
      return;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = openHour * 60 + openMinute;
    final closeMinutes = closeHour * 60 + closeMinute;
    final crossesMidnight = closeMinutes <= openMinutes;

    const dayKeys = <String>[
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];

    final enabledDays = data['enabledDays'];

    bool dayEnabled(String key) {
      if (enabledDays is Map) {
        return enabledDays[key] != false;
      }
      return true;
    }

    final todayKey = dayKeys[now.weekday - 1];
    final yesterdayKey = dayKeys[(now.weekday + 5) % 7];

    bool accepting;

    if (crossesMidnight) {
      accepting = (dayEnabled(todayKey) && nowMinutes >= openMinutes) ||
          (dayEnabled(yesterdayKey) && nowMinutes < closeMinutes);
    } else {
      accepting = dayEnabled(todayKey) &&
          nowMinutes >= openMinutes &&
          nowMinutes < closeMinutes;
    }

    if (!accepting) {
      final fallback =
          'بركة مغلق الآن — نستقبل الطلبات من $openingTime حتى $closingTime.';

      throw StateError(
        closedMessage?.isNotEmpty == true ? closedMessage! : fallback,
      );
    }
  }

  Future<void> _placeOrder() async {
    if (_payment == 'gateway' || _payment == 'card') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب ربط حساب الصرافة ببوابة الدفع الآمنة قبل استقبال دفع حقيقي.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_delivery == 'delivery' && _deliveryOutsideRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'عنوانك خارج نطاق توصيل هذا المتجر.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCouponId != null && _useBarakahPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'استخدم كوبون الخصم أو نقاط بركة، وليس الاثنين معًا.',
          ),
        ),
      );
      return;
    }

    if (_useBarakahPoints) {
      if (_selectedBarakahPoints <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اختر عدد نقاط بركة التي تريد استخدامها.',
            ),
          ),
        );
        return;
      }

      if (!RegExp(r'^\d{4}$').hasMatch(_barakahPin.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'أدخل الرقم السري لبطاقة بركة المكوّن من 4 أرقام.',
            ),
          ),
        );
        return;
      }

      if (_selectedBarakahPoints > _maxRedeemablePoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'عدد النقاط المختار غير متاح لهذا الطلب.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final cart = CartService.instance;

      await _ensureBarakahIsAcceptingOrders();

      if (cart.items.isEmpty) {
        throw StateError('السلة فارغة.');
      }

      final businessId = cart.items.first.businessId.trim();
      if (businessId.isEmpty) {
        throw StateError('تعذر تحديد المحل لهذا الطلب.');
      }

      final businessSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .doc(businessId)
          .get();

      final businessData = businessSnapshot.data();
      // بعض المحلات القديمة لا تملك وثيقة محل مستقلة رغم أن منتجاتها
      // صالحة. في هذه الحالة نترك التحقق النهائي للخادم، فهو يعيد بناء
      // بيانات المحل من المنتجات ويتحقق من السعر والمخزون بأمان.
      if (businessData != null) {
        final openingTime =
            businessData['openingTime']?.toString().trim() ?? '';
        final closingTime =
            businessData['closingTime']?.toString().trim() ?? '';

        final minimumOrderAmount =
            (businessData['minimumOrderAmount'] as num?) ?? 0;

        if (minimumOrderAmount > 0 && cart.total < minimumOrderAmount) {
          final missing = minimumOrderAmount - cart.total;

          String money(num value) {
            return value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toStringAsFixed(2);
          }

          throw StateError(
            'الحد الأدنى للطلب من هذا المتجر هو '
            '${money(minimumOrderAmount)} ₪. '
            'أضف ${money(missing)} ₪ لإتمام الطلب.',
          );
        }

        if (_scheduledFor != null) {
          if (!_scheduledFor!.isAfter(DateTime.now())) {
            throw StateError('اختر وقتًا لاحقًا للطلب.');
          }

          final scheduledStatus = BusinessHoursService.resolve(
            data: businessData,
            now: _scheduledFor,
          );

          if (!scheduledStatus.isAcceptingOrders) {
            if (scheduledStatus.code == 'temporarily_closed') {
              throw StateError(
                'المحل مغلق مؤقتًا ولا يمكن جدولة طلب له الآن.',
              );
            }

            final hoursText = openingTime.isNotEmpty && closingTime.isNotEmpty
                ? ' ساعات العمل: $openingTime - $closingTime.'
                : '';

            throw StateError(
              'الوقت المختار خارج ساعات عمل المحل.$hoursText',
            );
          }
        } else {
          final hoursStatus = BusinessHoursService.resolve(data: businessData);

          if (!hoursStatus.isAcceptingOrders) {
            var message = hoursStatus.label;

            if (hoursStatus.code == 'temporarily_closed') {
              message = 'المحل مغلق مؤقتًا ولا يستقبل طلبات الآن.';
            } else if (hoursStatus.code == 'opening_soon') {
              message = openingTime.isEmpty
                  ? 'المحل يفتح قريبًا.'
                  : 'المحل يفتح قريبًا الساعة $openingTime.';
            } else if (hoursStatus.code == 'closed') {
              message = openingTime.isEmpty
                  ? 'المحل مغلق الآن.'
                  : 'المحل مغلق الآن — يفتح الساعة $openingTime.';
            }

            throw StateError(message);
          }
        }
      } else if (_scheduledFor != null &&
          !_scheduledFor!.isAfter(DateTime.now())) {
        throw StateError('اختر وقتًا لاحقًا للطلب.');
      }

      await OrderService().createOrder(
        items: cart.items.map((item) => item.toOrderMap()).toList(),
        total: cart.total,
        deliveryMethod: _delivery,
        paymentMethod: _payment,
        barakahPointsToUse: _useBarakahPoints ? _selectedBarakahPoints : 0,
        barakahPin: _useBarakahPoints ? _barakahPin.text.trim() : null,
        couponId: _selectedCouponId,
        scheduledFor: _scheduledFor,
      );

      cart.clear();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلبك بنجاح.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e is StateError ? e.message.toString() : e.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Container(
        height: screenHeight * 0.88,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'إتمام الطلب',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.coolYellow.withOpacity(.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _CheckoutAmountRow(
                            title: 'مجموع الأصناف',
                            value:
                                '${CartService.instance.total.toStringAsFixed(2)} ₪',
                          ),
                          if (_delivery == 'delivery')
                            _CheckoutAmountRow(
                              title: 'رسوم التوصيل',
                              value: '${_deliveryFee.toStringAsFixed(2)} ₪',
                            ),
                          if (_delivery == 'delivery' &&
                              _deliveryDistanceKm != null)
                            _CheckoutAmountRow(
                              title: 'المسافة التقريبية',
                              value:
                                  '${_deliveryDistanceKm!.toStringAsFixed(1)} كم',
                            ),
                          if (_delivery == 'delivery' && _deliveryOutsideRange)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              child: Text(
                                'عنوانك خارج نطاق توصيل هذا المتجر.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (_selectedCouponId != null)
                            _CheckoutAmountRow(
                              title: 'خصم الكوبون',
                              value:
                                  '-${_selectedCouponDiscount.toStringAsFixed(2)} ₪',
                            ),
                          const Divider(),
                          _CheckoutAmountRow(
                            title: 'الإجمالي المتوقع',
                            value:
                                '${_estimatedPayableTotal.toStringAsFixed(2)} ₪',
                            emphasized: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceGroup(
                      title: 'طريقة الاستلام',
                      value: _delivery,
                      onChanged: (value) {
                        setState(() {
                          _delivery = value;

                          if (_selectedBarakahPoints > _maxRedeemablePoints) {
                            _selectedBarakahPoints = 0;
                          }
                        });
                      },
                      choices: const {
                        'delivery': 'دليفري إلى العنوان',
                        'pickup': 'استلام شخصي',
                      },
                    ),
                    const SizedBox(height: 8),
                    _ChoiceGroup(
                      title: 'طريقة الدفع',
                      value: _payment,
                      onChanged: (value) {
                        if (value != 'cash') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'الدفع الإلكتروني قريبًا.',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _payment = value);
                      },
                      choices: const {
                        'cash': 'الدفع عند الاستلام',
                      },
                    ),
                    if (_activeCoupons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.coolYellow.withOpacity(.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.deepYellow.withOpacity(.30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'كوبونات الخصم',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String?>(
                              value: _selectedCouponId,
                              decoration: const InputDecoration(
                                labelText: 'اختر كوبونًا',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('بدون كوبون'),
                                ),
                                ..._activeCoupons.map((coupon) {
                                  final data = coupon.data();
                                  final code =
                                      data['code']?.toString() ?? 'كوبون بركة';
                                  final percent =
                                      (data['discountPercent'] as num?) ?? 0;

                                  return DropdownMenuItem<String?>(
                                    value: coupon.id,
                                    child: Text(
                                      '$code — خصم $percent٪',
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCouponId = value;

                                  if (value != null) {
                                    _useBarakahPoints = false;
                                    _selectedBarakahPoints = 0;
                                    _barakahPin.clear();
                                  }
                                });
                              },
                            ),
                            if (_selectedCouponId != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'خصم الكوبون المتوقع: '
                                '${_selectedCouponDiscount.toStringAsFixed(2)} ₪',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (kLoyaltyRewardsEnabled)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.navy,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.coolYellow,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'الدفع بنقاط بركة',
                              style: TextStyle(
                                color: AppTheme.coolYellow,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'رصيدك: $_loyaltyPoints نقطة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_redemptionPoints نقطة = ${_redemptionValue.toStringAsFixed(_redemptionValue % 1 == 0 ? 0 : 2)} ₪',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppTheme.coolYellow,
                              value: _useBarakahPoints,
                              title: const Text(
                                'استخدام نقاط بركة لهذا الطلب',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _useBarakahPoints = value;

                                  if (value) {
                                    _selectedCouponId = null;

                                    if (_maxRedeemablePoints >=
                                        _redemptionPoints) {
                                      _selectedBarakahPoints =
                                          _redemptionPoints;
                                    }
                                  } else {
                                    _selectedBarakahPoints = 0;
                                    _barakahPin.clear();
                                  }
                                });
                              },
                            ),
                            if (_useBarakahPoints &&
                                _maxRedeemablePoints > 0) ...[
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                value: _selectedBarakahPoints > 0
                                    ? _selectedBarakahPoints
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'عدد النقاط المستخدمة',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                items: [
                                  for (int value = _redemptionPoints;
                                      value <= _maxRedeemablePoints;
                                      value += _redemptionPoints)
                                    DropdownMenuItem<int>(
                                      value: value,
                                      child: Text(
                                        '$value نقطة',
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBarakahPoints = value ?? 0;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _barakahPin,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: 'الرقم السري لبطاقة بركة (PIN)',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              if (_selectedBarakahPoints > 0) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.72),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          AppTheme.coolYellow.withOpacity(.55),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'إجمالي الطلب',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${_estimatedOrderTotal.toStringAsFixed(2)} ₪',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'خصم نقاط بركة',
                                            style: TextStyle(
                                              color: AppTheme.coolYellow,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '-${_selectedPointsDiscount.toStringAsFixed(2)} ₪',
                                            style: const TextStyle(
                                              color: AppTheme.coolYellow,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Divider(
                                          color: Colors.black26,
                                          height: 1,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'المتبقي للدفع',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            '${_estimatedPayableTotal.toStringAsFixed(2)} ₪',
                                            style: const TextStyle(
                                              color: AppTheme.coolYellow,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            if (_useBarakahPoints && _maxRedeemablePoints == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'رصيدك الحالي لا يكفي لفئة الاستبدال أو قيمة الطلب أقل من فئة الخصم.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _scheduledFor != null,
                      title: const Text(
                        'جدولة الطلب لوقت لاحق',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        _scheduledFor == null
                            ? 'مفيد عندما يكون المحل مغلقًا الآن'
                            : '${_scheduledFor!.day}/${_scheduledFor!.month} — ${TimeOfDay.fromDateTime(_scheduledFor!).format(context)}',
                      ),
                      onChanged: (value) async {
                        if (!value) {
                          setState(() => _scheduledFor = null);
                          return;
                        }

                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          initialDate: DateTime.now(),
                        );

                        if (date == null || !context.mounted) {
                          return;
                        }

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (time == null || !context.mounted) {
                          return;
                        }

                        final selectedSchedule = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );

                        if (!selectedSchedule.isAfter(DateTime.now())) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اختر وقتًا لاحقًا للطلب.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }

                        try {
                          final cart = CartService.instance;

                          if (cart.items.isEmpty) {
                            return;
                          }

                          final businessId = cart.items.first.businessId.trim();

                          if (businessId.isEmpty) {
                            throw StateError(
                              'تعذر تحديد المحل لهذا الطلب.',
                            );
                          }

                          final businessSnapshot = await FirebaseFirestore
                              .instance
                              .collection('items')
                              .doc(businessId)
                              .get();

                          final businessData = businessSnapshot.data();

                          if (businessData == null) {
                            throw StateError(
                              'تعذر تحميل ساعات عمل المحل.',
                            );
                          }

                          final scheduledStatus = BusinessHoursService.resolve(
                            data: businessData,
                            now: selectedSchedule,
                          );

                          if (!scheduledStatus.isAcceptingOrders) {
                            final openingTime = businessData['openingTime']
                                    ?.toString()
                                    .trim() ??
                                '';

                            final closingTime = businessData['closingTime']
                                    ?.toString()
                                    .trim() ??
                                '';

                            final hoursText = openingTime.isNotEmpty &&
                                    closingTime.isNotEmpty
                                ? ' ساعات العمل: $openingTime - $closingTime.'
                                : '';

                            final message = scheduledStatus.code ==
                                    'temporarily_closed'
                                ? 'المحل مغلق مؤقتًا ولا يمكن جدولة طلب له الآن.'
                                : 'هذا الوقت خارج ساعات عمل المحل.$hoursText';

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            return;
                          }

                          if (mounted) {
                            setState(() {
                              _scheduledFor = selectedSchedule;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is StateError
                                      ? e.message.toString()
                                      : 'تعذر التحقق من ساعات عمل المحل.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.deepYellow,
                ),
                onPressed: _saving ? null : _placeOrder,
                child: _saving
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                      )
                    : const Text(
                        'تأكيد الطلب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutAmountRow extends StatelessWidget {
  const _CheckoutAmountRow({
    required this.title,
    required this.value,
    this.emphasized = false,
  });

  final String title;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: emphasized ? AppTheme.deepYellow : AppTheme.navy,
                fontSize: emphasized ? 17 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.choices,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, String> choices;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          ...choices.entries.map(
            (entry) => RadioListTile<String>(
              value: entry.key,
              groupValue: value,
              activeColor: AppTheme.deepYellow,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
            ),
          ),
        ],
      );
}

class _EmptyCartArtwork extends StatelessWidget {
  const _EmptyCartArtwork();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 285,
        child: Center(
          child: Image.asset(
            'assets/images/barakah_cart_bunny_basket.png',
            width: 290,
            height: 275,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 210,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.coolYellow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                size: 100,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
}
