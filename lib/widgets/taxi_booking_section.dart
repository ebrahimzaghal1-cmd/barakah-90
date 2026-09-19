import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/taxi_order_service.dart';
import '../theme/app_theme.dart';
import 'taxi_customer_live_map.dart';

class TaxiBookingSection extends StatefulWidget {
  const TaxiBookingSection({super.key});

  @override
  State<TaxiBookingSection> createState() => _TaxiBookingSectionState();
}

class _TaxiBookingSectionState extends State<TaxiBookingSection> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildGuestCard(context);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TaxiOrderService.instance.watchCustomerActiveOrders(
        customerId: user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isNotEmpty) {
          final activeTrip = docs.first.data();
          final orderId = docs.first.id;
          return _buildActiveTripCard(context, orderId, activeTrip);
        }

        return _buildBookingCard(context, user);
      },
    );
  }

  Widget _buildGuestCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.coolYellow.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded, size: 52, color: AppTheme.navy),
          const SizedBox(height: 10),
          const Text(
            'خدمة التاكسي السريع بكبسة زر',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سجّل الدخول أولاً لتتمكن من طلب التاكسي بضغطة زر وتوثيق رحلتك وحفظ حقوقك المالية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل الدخول لطلب تاكسي'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navy,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.95),
            AppTheme.coolYellow.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppTheme.coolYellow.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Colors.amber,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تكسي بركة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'متاح على مدار الساعة • طلب فوري',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الطلب بضغطة زر يحفظ حقك ويوثق مشوارك المالي رسمياً.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showOrderSheet(context, user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.local_taxi_rounded,
                  color: Colors.amber, size: 26),
              label: const Text(
                '🚖 اطلب تكسي الآن بكبسة زر',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> trip,
  ) {
    final status = trip['status']?.toString() ?? 'pending';
    final isDispatched = status == 'dispatched';
    final awaitingConfirmation = status == 'awaiting_customer_confirmation';
    final orderNumber = trip['orderNumber']?.toString() ?? '#TK';
    final vehicle = trip['dispatchedVehicle']?.toString();
    final eta = trip['dispatchedEtaMinutes']?.toString() ?? '5';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDispatched ? Colors.green : Colors.amber.shade700,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDispatched ? Colors.green : Colors.amber).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDispatched ? Colors.green : Colors.amber)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDispatched
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      size: 16,
                      color: isDispatched
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isDispatched
                          ? 'انطلقت السيارة إليك'
                          : 'جاري توجيه سيارة إليك...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDispatched
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                orderNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (awaitingConfirmation) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.green.withOpacity(0.25),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Colors.green,
                    size: 38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'تم تسجيل انتهاء المشوار',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'إذا وصلت إلى وجهتك، أكّد انتهاء الرحلة لتثبيت العملية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else if (isDispatched) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_filled_rounded,
                      color: Colors.green, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle?.isNotEmpty == true
                              ? vehicle!
                              : 'سيارة التاكسي في طريقها إليك',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'وقت الوصول المتوقع: $eta دقائق تقريباً',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TaxiCustomerLiveMap(
              driverLatitude: trip['driverLatitude'],
              driverLongitude: trip['driverLongitude'],
              driverLocationUpdatedAt: trip['driverLocationUpdatedAt'],
            ),
            const SizedBox(height: 14),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 12),
                    Text(
                      'جاري إشعار مكتب التاكسي بالطلب لتوجيه أقرب سيارة...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'موقع الركوب: ${trip['pickupAddress'] ?? 'الموقع الحالي'}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الوجهة: ${trip['destination'] ?? 'غير محدد'}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (awaitingConfirmation) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Column(
                children: [
                  const Text(
                    'الأجرة المسجلة من مكتب التكسي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${trip['fareAmount'] ?? '—'} ₪',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'تأكد من صحة الأجرة قبل تأكيد انتهاء الرحلة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _confirmArrival(context, orderId),
              icon: const Icon(Icons.verified_rounded),
              label: const Text(
                'نعم، وصلت — تأكيد انتهاء الرحلة',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا تُثبت عمولة بركة إلا بعد تأكيد انتهاء الرحلة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (!isDispatched)
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, orderId),
              icon:
                  const Icon(Icons.close_rounded, color: Colors.red, size: 18),
              label: const Text(
                'إلغاء الطلب',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.4)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmArrival(
    BuildContext context,
    String orderId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد انتهاء الرحلة'),
        content: const Text(
          'هل وصلت إلى وجهتك وانتهت رحلة التكسي فعلًا؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ليس بعد'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، وصلت'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await TaxiOrderService.instance.confirmArrival(
        orderId: orderId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد انتهاء الرحلة بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تأكيد انتهاء الرحلة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmCancel(BuildContext context, String orderId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء طلب التاكسي'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await TaxiOrderService.instance.cancelTrip(orderId: orderId);
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  void _showOrderSheet(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TaxiOrderSheet(
        user: user,
      ),
    );
  }
}

class _TaxiOrderSheet extends StatefulWidget {
  const _TaxiOrderSheet({
    required this.user,
  });

  final User user;

  @override
  State<_TaxiOrderSheet> createState() => _TaxiOrderSheetState();
}

class _TaxiOrderSheetState extends State<_TaxiOrderSheet> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  double? _pickupLat;
  double? _pickupLng;
  bool _loadingLocation = false;
  bool _submitting = false;

  final _quickDestinations = [
    'وسط البلد - الدوار',
    'جامعة خضوري',
    'مفرق فرعون',
    'الحي الشرقي',
    'اكتابا',
    'مستشفى الشهيد ثابت ثابت',
    'ضاحية ذنابة',
    'ضاحية الشويكة',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
        _pickupController.text = 'موقعي الحالي عبر الـ GPS';
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        if (_pickupController.text.isEmpty) {
          _pickupController.text = 'طولكرم - موقعي الحالي';
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    final pickup = _pickupController.text.trim();
    final destination = _destinationController.text.trim();

    if (pickup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد موقع الركوب.')),
      );
      return;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة الوجهة أو اختيارها.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await TaxiOrderService.instance.createOrder(
        pickupAddress: pickup,
        pickupLatitude: _pickupLat,
        pickupLongitude: _pickupLng,
        destination: destination,
        notes: _notesController.text.trim(),
        customerName: widget.user.displayName,
        customerPhone: widget.user.phoneNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب التاكسي بنجاح! جاري توجيه سيارة إليك ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الطلب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.of(context).viewInsets.bottom + 26,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.local_taxi_rounded,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'طلب تكسي بركة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Pickup location
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'موقع الركوب (أين أنت؟)',
                prefixIcon:
                    const Icon(Icons.my_location_rounded, color: AppTheme.navy),
                suffixIcon: _loadingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.gps_fixed_rounded,
                            color: Colors.green),
                        tooltip: 'تحديث الموقع عبر GPS',
                        onPressed: _fetchCurrentLocation,
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            // Destination
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'الوجهة (إلى أين تريد الذهاب؟)',
                hintText: 'مثال: جامعة خضوري، مفرق فرعون...',
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: Colors.redAccent),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            // Quick suggestions
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickDestinations.map((dest) {
                return ActionChip(
                  label: Text(dest, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.coolYellow.withOpacity(0.18),
                  side: BorderSide.none,
                  onPressed: () {
                    setState(() {
                      _destinationController.text = dest;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات للكابتن (اختياري)',
                hintText: 'مثال: أمام البنك، 3 ركاب، حقائب سفر...',
                prefixIcon:
                    const Icon(Icons.edit_note_rounded, color: Colors.blueGrey),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطلب بضغطة زر يضمن توثيق الرحلة، استحقاق المنصة، وحمايتك.',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.amber),
                label: Text(
                  _submitting
                      ? 'جاري إرسال الطلب...'
                      : 'تأكيد وإرسال التاكسي الآن',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
