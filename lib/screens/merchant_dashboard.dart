import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../admin/admin_manage_products.dart';
import 'location_picker_screen.dart';
import 'restaurant_details_screen.dart';
import '../services/order_service.dart';
import '../services/barber_booking_service.dart';
import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';

class MerchantDashboard extends StatelessWidget {
  const MerchantDashboard({super.key});

  Future<String> _uploadStoreImage(XFile image) async {
    return MediaUploadService().upload(image, isVideo: false);
  }

  Future<void> _editBusiness(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> business,
  ) async {
    final data = business.data();
    final title = TextEditingController(text: data['title']?.toString() ?? '');
    final description =
        TextEditingController(text: data['description']?.toString() ?? '');
    final phone = TextEditingController(text: data['phone']?.toString() ?? '');
    final address =
        TextEditingController(text: data['address']?.toString() ?? '');
    final preparationMinutes = TextEditingController(
        text: (data['preparationMinutes'] ?? 30).toString());
    final minimumOrderAmount = TextEditingController(
        text: (data['minimumOrderAmount'] ?? 0).toString());

    final rawDeliveryZones = data['deliveryZones'];
    final deliveryZones = rawDeliveryZones is List
        ? rawDeliveryZones
            .whereType<Map>()
            .map((zone) => Map<String, dynamic>.from(zone))
            .toList()
        : <Map<String, dynamic>>[];

    String zoneValue(int index, String key, String fallback) {
      if (index >= deliveryZones.length) return fallback;
      return (deliveryZones[index][key] ?? fallback).toString();
    }

    final deliveryZone1Km =
        TextEditingController(text: zoneValue(0, 'maxKm', '3'));
    final deliveryZone1Fee =
        TextEditingController(text: zoneValue(0, 'fee', '5'));
    final deliveryZone2Km =
        TextEditingController(text: zoneValue(1, 'maxKm', '7'));
    final deliveryZone2Fee =
        TextEditingController(text: zoneValue(1, 'fee', '8'));
    final deliveryZone3Km =
        TextEditingController(text: zoneValue(2, 'maxKm', '12'));
    final deliveryZone3Fee =
        TextEditingController(text: zoneValue(2, 'fee', '12'));
    final openingTime =
        TextEditingController(text: data['openingTime']?.toString() ?? '08:00');
    final closingTime =
        TextEditingController(text: data['closingTime']?.toString() ?? '23:00');

    var imageUrl = data['image']?.toString().trim() ?? '';
    XFile? selectedImage;
    double? latitude = (data['latitude'] as num?)?.toDouble();
    double? longitude = (data['longitude'] as num?)?.toDouble();

    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل بيانات محلي'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: saving
                    ? null
                    : () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 82,
                        );

                        if (picked == null) return;

                        setDialogState(() {
                          selectedImage = picked;
                        });
                      },
                child: Container(
                  width: 420,
                  height: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.coolYellow.withOpacity(.65),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (selectedImage != null)
                        FutureBuilder<List<int>>(
                          future: selectedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            return Image.memory(
                              Uint8List.fromList(snapshot.data!),
                              width: 420,
                              height: 180,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      else if (imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          width: 420,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            size: 58,
                          ),
                        )
                      else
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 58,
                        ),
                      Positioned(
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            imageUrl.isEmpty && selectedImage == null
                                ? 'إضافة صورة للمتجر'
                                : 'تغيير صورة المتجر',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                    labelText: 'اسم المحل أو المطعم',
                    prefixIcon: Icon(Icons.storefront_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'وصف المحل',
                    prefixIcon: Icon(Icons.description_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'رقم التواصل',
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final location =
                              await Navigator.push<Map<String, double>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LocationPickerScreen(
                                latitude: latitude,
                                longitude: longitude,
                              ),
                            ),
                          );
                          if (location != null) {
                            setDialogState(() {
                              latitude = location['latitude'];
                              longitude = location['longitude'];
                            });
                          }
                        },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    latitude == null
                        ? 'تحديد موقع المحل على الخريطة *'
                        : 'تم تحديد الموقع — تغيير',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: preparationMinutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'مدة تجهيز الطلب الافتراضية بالدقائق',
                    prefixIcon: Icon(Icons.timer_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minimumOrderAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للطلب',
                  hintText: 'مثال: 30',
                  suffixText: '₪',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'نطاقات ورسوم التوصيل',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'حدد أقصى مسافة ورسوم كل نطاق. يجب أن تكون المسافات تصاعدية.',
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: deliveryZone1Km,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'النطاق الأول',
                        suffixText: 'كم',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: deliveryZone1Fee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'رسوم التوصيل',
                        suffixText: '₪',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: deliveryZone2Km,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'النطاق الثاني',
                        suffixText: 'كم',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: deliveryZone2Fee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'رسوم التوصيل',
                        suffixText: '₪',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: deliveryZone3Km,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'النطاق الثالث',
                        suffixText: 'كم',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: deliveryZone3Fee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'رسوم التوصيل',
                        suffixText: '₪',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                  controller: openingTime,
                  decoration: const InputDecoration(
                      labelText: 'وقت الفتح', hintText: '08:00'),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                  controller: closingTime,
                  decoration: const InputDecoration(
                      labelText: 'وقت الإغلاق', hintText: '23:00'),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          address.text.trim().isEmpty ||
                          latitude == null ||
                          longitude == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'اسم المحل والعنوان والموقع على الخريطة مطلوبة.',
                            ),
                          ),
                        );
                        return;
                      }
                      final deliveryZone1KmValue =
                          num.tryParse(deliveryZone1Km.text.trim());
                      final deliveryZone1FeeValue =
                          num.tryParse(deliveryZone1Fee.text.trim());
                      final deliveryZone2KmValue =
                          num.tryParse(deliveryZone2Km.text.trim());
                      final deliveryZone2FeeValue =
                          num.tryParse(deliveryZone2Fee.text.trim());
                      final deliveryZone3KmValue =
                          num.tryParse(deliveryZone3Km.text.trim());
                      final deliveryZone3FeeValue =
                          num.tryParse(deliveryZone3Fee.text.trim());

                      if (deliveryZone1KmValue == null ||
                          deliveryZone1FeeValue == null ||
                          deliveryZone2KmValue == null ||
                          deliveryZone2FeeValue == null ||
                          deliveryZone3KmValue == null ||
                          deliveryZone3FeeValue == null ||
                          deliveryZone1KmValue <= 0 ||
                          deliveryZone2KmValue <= deliveryZone1KmValue ||
                          deliveryZone3KmValue <= deliveryZone2KmValue ||
                          deliveryZone1FeeValue < 0 ||
                          deliveryZone2FeeValue < 0 ||
                          deliveryZone3FeeValue < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تحقق من نطاقات التوصيل: المسافات يجب أن تكون موجبة وتصاعدية والرسوم لا تقل عن صفر.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        if (selectedImage != null) {
                          imageUrl = await _uploadStoreImage(selectedImage!);
                        }

                        await business.reference.update({
                          'title': title.text.trim(),
                          'image': imageUrl,
                          'description': description.text.trim(),
                          'phone': phone.text.trim(),
                          'address': address.text.trim(),
                          'latitude': latitude,
                          'longitude': longitude,
                          'preparationMinutes':
                              int.tryParse(preparationMinutes.text.trim()) ??
                                  30,
                          'minimumOrderAmount':
                              num.tryParse(minimumOrderAmount.text.trim()) ?? 0,
                          'deliveryZones': [
                            {
                              'maxKm': deliveryZone1KmValue,
                              'fee': deliveryZone1FeeValue,
                            },
                            {
                              'maxKm': deliveryZone2KmValue,
                              'fee': deliveryZone2FeeValue,
                            },
                            {
                              'maxKm': deliveryZone3KmValue,
                              'fee': deliveryZone3FeeValue,
                            },
                          ],
                          'openingTime': openingTime.text.trim(),
                          'closingTime': closingTime.text.trim(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تعذر حفظ بيانات المحل.')),
                          );
                        }
                        setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    phone.dispose();
    address.dispose();
    preparationMinutes.dispose();
    minimumOrderAmount.dispose();
    deliveryZone1Km.dispose();
    deliveryZone1Fee.dispose();
    deliveryZone2Km.dispose();
    deliveryZone2Fee.dispose();
    deliveryZone3Km.dispose();
    deliveryZone3Fee.dispose();
    openingTime.dispose();
    closingTime.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة متجري'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر قراءة حساب التاجر: ${profileSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!profileSnapshot.hasData) {
            return const Center(
              child: Text(
                'جاري قراءة حساب التاجر...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          }

          final profile = profileSnapshot.data?.data() ?? <String, dynamic>{};

          final merchantBusinessId =
              profile['merchantBusinessId']?.toString().trim() ?? '';

          final businessStream = merchantBusinessId.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('items')
                  .where(
                    FieldPath.documentId,
                    isEqualTo: merchantBusinessId,
                  )
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('items')
                  .where('ownerId', isEqualTo: user.uid)
                  .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: businessStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل المتجر: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    merchantBusinessId.isEmpty
                        ? 'جاري البحث عن متجر الحساب بواسطة ownerId...'
                        : 'جاري فتح المتجر رقم: $merchantBusinessId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }

              final businesses = snapshot.data!.docs
                  .where((doc) => doc.data()['kind'] != 'product')
                  .toList();
              if (businesses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'لم يتم العثور على متجر مرتبط بهذا الحساب.\n\n'
                        'UID: ${user.uid}\n'
                        'merchantBusinessId: '
                        '${merchantBusinessId.isEmpty ? "غير موجود" : merchantBusinessId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: businesses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  final data = business.data();
                  final businessStatus =
                      data['businessStatus']?.toString() ?? 'open';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.coolYellow,
                            backgroundImage:
                                data['image']?.toString().isNotEmpty == true
                                    ? NetworkImage(data['image'].toString())
                                    : null,
                            child: data['image']?.toString().isNotEmpty == true
                                ? null
                                : const Icon(Icons.storefront),
                          ),
                          title: Text(data['title']?.toString() ?? 'متجري',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(data['category']?.toString() ?? ''),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: const ['open', 'busy', 'closed']
                                  .contains(businessStatus)
                              ? businessStatus
                              : 'open',
                          decoration: const InputDecoration(
                            labelText: 'حالة المحل للزبائن',
                            prefixIcon:
                                Icon(Icons.store_mall_directory_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'open',
                                child: Text('مفتوح — يستقبل الطلبات')),
                            DropdownMenuItem(
                                value: 'busy',
                                child: Text('مشغول — قد يتأخر الطلب')),
                            DropdownMenuItem(
                                value: 'closed',
                                child: Text('مغلق — لا يستقبل طلبات')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              business.reference
                                  .update({'businessStatus': value});
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RestaurantDetailsScreen(
                                  restaurant: business,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text(
                              'عرض متجري كما يراه الزبون',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _editBusiness(context, business),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل بيانات محلي'),
                          ),
                        ),
                        if (data['type']?.toString().toLowerCase() ==
                            'market') ...[
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('market_categories')
                                .snapshots(),
                            builder: (context, categorySnapshot) {
                              final categories =
                                  categorySnapshot.data?.docs ?? const [];

                              if (categories.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.coolYellow.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'لا توجد أقسام في سوق بركة بعد. أضيفي الأقسام من لوحة الأدمن.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }

                              final titles = categories
                                  .map(
                                    (doc) =>
                                        doc
                                            .data()['title']
                                            ?.toString()
                                            .trim() ??
                                        '',
                                  )
                                  .where((title) => title.isNotEmpty)
                                  .toSet()
                                  .toList();

                              final currentCategory =
                                  data['category']?.toString().trim() ?? '';

                              return DropdownButtonFormField<String>(
                                value: titles.contains(currentCategory)
                                    ? currentCategory
                                    : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'قسم متجري في سوق بركة',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                hint: const Text(
                                    'اختاري القسم الذي يظهر فيه متجرك'),
                                items: titles
                                    .map(
                                      (title) => DropdownMenuItem<String>(
                                        value: title,
                                        child: Text(
                                          title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null || value.isEmpty) return;

                                  await business.reference.update({
                                    'category': value,
                                    'type': 'market',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تم ربط متجرك بقسم $value ✅',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminManageProducts(
                                  initialBusinessId: business.id,
                                  initialBusinessTitle:
                                      data['title']?.toString(),
                                  ownerUid: user.uid,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('إدارة المنتجات والأسعار'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MerchantCoupons(businessId: business.id),
                        const SizedBox(height: 8),
                        _MerchantOrders(businessId: business.id),
                        if (data['type']?.toString().toLowerCase() ==
                            'barber') ...[
                          const SizedBox(height: 8),
                          _MerchantBarberBookings(businessId: business.id),
                        ],
                        if (data['type']?.toString().toLowerCase() ==
                            'doctor') ...[
                          const SizedBox(height: 8),
                          _MerchantDoctorConsultations(doctorId: business.id),
                          const SizedBox(height: 8),
                          _MerchantBarberBookings(businessId: business.id),
                        ],
                      ]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MerchantCoupons extends StatefulWidget {
  const _MerchantCoupons({
    required this.businessId,
  });

  final String businessId;

  @override
  State<_MerchantCoupons> createState() => _MerchantCouponsState();
}

class _MerchantCouponsState extends State<_MerchantCoupons> {
  bool _loading = true;

  List<Map<String, dynamic>> _coupons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await OrderService().merchantCoupons();

      if (!mounted) return;

      setState(() {
        _coupons = all.where((coupon) {
          return coupon['businessId']?.toString() == widget.businessId;
        }).toList();

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'تعذر تحميل كوبونات المتجر.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addCoupon() async {
    final code = TextEditingController();

    final discount = TextEditingController(text: '10');

    final minimum = TextEditingController(text: '0');

    final maxUses = TextEditingController(text: '0');

    final days = TextEditingController(text: '30');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'إضافة كوبون للمتجر',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'رمز الكوبون',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة الخصم %',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minimum,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأدنى للطلب',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxUses,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'أقصى عدد استخدامات — 0 غير محدود',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الصلاحية بالأيام — 0 بدون انتهاء',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
              ),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final percent = num.tryParse(
                  discount.text.trim(),
                );

                final minimumValue = num.tryParse(
                      minimum.text.trim(),
                    ) ??
                    0;

                final maxUsesValue = int.tryParse(
                      maxUses.text.trim(),
                    ) ??
                    0;

                final daysValue = int.tryParse(
                      days.text.trim(),
                    ) ??
                    0;

                final couponCode = code.text.trim().toUpperCase();

                if (!RegExp(r'^[A-Z0-9_-]{3,32}$').hasMatch(couponCode)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'رمز الكوبون يسمح بالحروف الإنجليزية والأرقام و - أو _ فقط، من 3 إلى 32 خانة.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (percent == null || percent <= 0 || percent > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نسبة الخصم يجب أن تكون بين 1 و100.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final result = await OrderService().createMerchantCoupon(
                    businessId: widget.businessId,
                    code: couponCode,
                    discountPercent: percent,
                    minimumOrderAmount: minimumValue,
                    maxUses: maxUsesValue,
                    expiresAt: daysValue > 0
                        ? DateTime.now().add(Duration(days: daysValue))
                        : null,
                  );

                  debugPrint('MERCHANT_COUPON_CREATE_RESULT: $result');

                  await _load();

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم إنشاء الكوبون $couponCode ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (error, stackTrace) {
                  debugPrint('MERCHANT_COUPON_CREATE_ERROR: $error');
                  debugPrint('$stackTrace');

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error is StateError
                            ? error.message.toString()
                            : 'تعذر إنشاء الكوبون: $error',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    code.dispose();
    discount.dispose();
    minimum.dispose();
    maxUses.dispose();
    days.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.discount_rounded,
      ),
      title: const Text(
        'إدارة كوبونات متجري',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: const Text(
        'أنشئ كوبونات خصم خاصة بهذا المتجر',
      ),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addCoupon,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'إضافة كوبون',
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_coupons.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'لا توجد كوبونات لهذا المتجر.',
            ),
          )
        else
          ..._coupons.map(
            (coupon) => ListTile(
              leading: const Icon(
                Icons.local_offer_rounded,
              ),
              title: Text(
                '${coupon['code'] ?? ''} — خصم ${coupon['discountPercent'] ?? 0}٪',
              ),
              subtitle: Text(
                'الاستخدام: ${coupon['usedCount'] ?? 0}',
              ),
            ),
          ),
      ],
    );
  }
}

class _MerchantBarberBookings extends StatelessWidget {
  const _MerchantBarberBookings({required this.businessId});
  final String businessId;

  static const _labels = {
    'pending': 'بانتظار التأكيد',
    'confirmed': 'مؤكد',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'no_show': 'لم يحضر',
  };

  Future<void> _setStatus(
      BuildContext context, String id, String status) async {
    try {
      await BarberBookingService.instance.updateBookingStatus(
        bookingId: id,
        status: status,
        businessId: businessId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث حالة الموعد ✅')));
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر تحديث الموعد.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_month_rounded),
        title: const Text('مواعيد الحلاق',
            style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle:
            const Text('تظهر هنا حجوزات الزبائن من الموقع وعمولة بركة 10%'),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                BarberBookingService.instance.watchMerchantBookings(businessId),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator());
              final bookings = snapshot.data!.docs.toList()
                ..sort((a, b) => ((a.data()['scheduledAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0)
                    .compareTo((b.data()['scheduledAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0));
              if (bookings.isEmpty)
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد حجوزات مواعيد حتى الآن.'));
              return Column(
                  children: bookings.take(30).map((booking) {
                final data = booking.data();
                final status = data['status']?.toString() ?? 'pending';
                final scheduled = (data['scheduledAt'] as Timestamp?)?.toDate();
                final date = scheduled == null
                    ? data['dateKey']?.toString() ?? ''
                    : '${scheduled.day}/${scheduled.month}/${scheduled.year} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                        '${data['customerName'] ?? 'زبون'} — ${data['serviceTitle'] ?? 'خدمة'}',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                        '$date\n${data['customerPhone'] ?? ''} • ${_labels[status] ?? status}\nقيمة: ${data['price'] ?? 0} ₪ — عمولة بركة: ${data['commissionAmount'] ?? 0} ₪'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _setStatus(context, booking.id, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'confirmed', child: Text('تأكيد الموعد')),
                        PopupMenuItem(
                            value: 'completed', child: Text('تمت الخدمة')),
                        PopupMenuItem(value: 'no_show', child: Text('لم يحضر')),
                        PopupMenuItem(value: 'cancelled', child: Text('إلغاء')),
                      ],
                    ),
                  ),
                );
              }).toList());
            },
          ),
        ],
      );
}

class _MerchantDoctorConsultations extends StatelessWidget {
  const _MerchantDoctorConsultations({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.chat_bubble_outline_rounded),
        title: const Text('طلبات الاستشارة الطبية',
            style: TextStyle(fontWeight: FontWeight.w900)),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('doctor_consultations')
                .where('doctorId', isEqualTo: doctorId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد طلبات استشارة حتى الآن.'));
              }
              return Column(
                  children: snapshot.data!.docs.take(30).map((doc) {
                final data = doc.data();
                return Card(
                  child: ListTile(
                    title: Text(data['message']?.toString() ?? '',
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text('الحالة: ${data['status'] ?? 'pending'}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) => doc.reference.update({
                        'status': status,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'in_progress', child: Text('قيد المتابعة')),
                        PopupMenuItem(
                            value: 'answered', child: Text('تم الرد')),
                        PopupMenuItem(value: 'closed', child: Text('إغلاق')),
                      ],
                    ),
                  ),
                );
              }).toList());
            },
          ),
        ],
      );
}

class _MerchantOrders extends StatelessWidget {
  const _MerchantOrders({required this.businessId});
  final String businessId;

  static const labels = {
    'scheduled': 'مجدول',
    'new': 'جديد',
    'accepted': 'تم القبول',
    'preparing': 'قيد التحضير',
    'ready': 'جاهز للسائق',
    'driver_assigned': 'تم تعيين سائق',
    'picked_up': 'مع السائق',
    'delivered': 'تم التسليم',
    'rejected': 'مرفوض',
  };

  Future<void> _status(String orderId, String status) =>
      OrderService().updateStatus(orderId, status);

  Future<void> _changeStatus(
    BuildContext context,
    String orderId,
    String status,
  ) async {
    try {
      await _status(orderId, status);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث الطلب إلى ${labels[status]}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'تعذر تحديث الطلب الآن.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.receipt_long_rounded),
        title: const Text('طلبات هذا المحل',
            style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('قبول الطلب ثم بدء التحضير وتحديد أنه جاهز'),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('businessId', isEqualTo: businessId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator());
              }
              final orders = snapshot.data!.docs.toList()
                ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0)
                    .compareTo((a.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0));
              if (orders.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد طلبات لهذا المحل.'));
              }
              return Column(
                  children: orders.take(10).map((order) {
                final data = order.data();
                final status = data['status']?.toString() ?? 'new';
                final deliveryMethod =
                    data['deliveryMethod']?.toString() ?? 'delivery';
                final scheduled = data['scheduledFor'] as Timestamp?;
                final scheduledDue = scheduled == null ||
                    !scheduled.toDate().isAfter(DateTime.now());
                final actionable =
                    ['new', 'accepted', 'preparing'].contains(status) ||
                        (status == 'scheduled' && scheduledDue) ||
                        (status == 'ready' && deliveryMethod == 'pickup');
                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('طلب ${data['orderNumber'] ?? order.id}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          Text(
                            '${status == 'ready' && deliveryMethod == 'pickup' ? 'جاهز للاستلام' : labels[status] ?? status} • ${data['total'] ?? 0} ₪',
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.035),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'قيمة المنتجات',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${data['subtotal'] ?? data['total'] ?? 0} ₪',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                if ((data['barakahPointsDiscount'] as num?) !=
                                        null &&
                                    ((data['barakahPointsDiscount'] as num?) ??
                                            0) >
                                        0) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'خصم نقاط بركة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '-${data['barakahPointsDiscount']} ₪',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'دفع الزبون',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${data['payableTotal'] ?? data['total'] ?? 0} ₪',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'عمولة بركة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${data['commissionAmount'] ?? 0} ₪',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'صافي المحل',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${data['businessNet'] ?? 0} ₪',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (data['scheduledFor'] is Timestamp)
                            Text(
                                'موعده: ${(data['scheduledFor'] as Timestamp).toDate().toLocal()}'),
                          if (actionable) ...[
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              if (status == 'new' ||
                                  (status == 'scheduled' && scheduledDue))
                                FilledButton(
                                    onPressed: () => _changeStatus(
                                        context, order.id, 'accepted'),
                                    child: const Text('قبول')),
                              if (status == 'new' ||
                                  (status == 'scheduled' && scheduledDue))
                                OutlinedButton(
                                    onPressed: () => _changeStatus(
                                        context, order.id, 'rejected'),
                                    child: const Text('رفض')),
                              if (status == 'accepted')
                                FilledButton(
                                    onPressed: () => _changeStatus(
                                        context, order.id, 'preparing'),
                                    child: const Text('بدء التحضير')),
                              if (status == 'preparing')
                                FilledButton(
                                    onPressed: () => _changeStatus(
                                        context, order.id, 'ready'),
                                    child: const Text('الطلب جاهز')),
                              if (status == 'ready' &&
                                  deliveryMethod == 'pickup')
                                FilledButton(
                                    onPressed: () => _changeStatus(
                                        context, order.id, 'delivered'),
                                    child: const Text('تأكيد التسليم')),
                            ]),
                          ],
                        ]),
                  ),
                );
              }).toList());
            },
          )
        ],
      );
}
