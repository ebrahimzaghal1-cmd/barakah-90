import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/location_picker_screen.dart';
import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';
import 'admin_manage_products.dart';

class AdminManageRestaurants extends StatefulWidget {
  const AdminManageRestaurants({
    super.key,
    this.itemType = 'restaurant',
    this.singularLabel = 'مطعم',
    this.pluralLabel = 'المطاعم',
  });

  final String itemType;
  final String singularLabel;
  final String pluralLabel;

  @override
  State<AdminManageRestaurants> createState() => _AdminManageRestaurantsState();
}

class _AdminManageRestaurantsState extends State<AdminManageRestaurants> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Future<String> _uploadImage(File image) async {
    return MediaUploadService().upload(
      XFile(image.path),
      isVideo: false,
    );
  }

  Future<void> _showRestaurantDialog({DocumentSnapshot? doc}) async {
    final restaurant = doc?.data() as Map<String, dynamic>? ?? {};
    final titleController =
        TextEditingController(text: restaurant['title'] ?? '');
    final descriptionController =
        TextEditingController(text: restaurant['description'] ?? '');
    final categoryController =
        TextEditingController(text: restaurant['category'] ?? '');
    final typeController =
        TextEditingController(text: restaurant['type'] ?? widget.itemType);
    final ratingController =
        TextEditingController(text: '${restaurant['rating'] ?? ''}');
    final discountController =
        TextEditingController(text: '${restaurant['discountPercent'] ?? ''}');
    final deliveryFeeController =
        TextEditingController(text: '${restaurant['deliveryFee'] ?? ''}');
    final commissionController =
        TextEditingController(text: '${restaurant['commissionRate'] ?? 10}');
    final ownerEmailController =
        TextEditingController(text: restaurant['ownerEmail'] ?? '');
    final preparationController = TextEditingController(
        text: (restaurant['preparationMinutes'] ?? 30).toString());

    final defaultOpeningTime = widget.itemType == 'market' ? '10:00' : '08:00';
    final defaultClosingTime = widget.itemType == 'market' ? '03:00' : '23:00';

    final openingTimeController = TextEditingController(
      text: restaurant['openingTime']?.toString() ?? defaultOpeningTime,
    );

    final closingTimeController = TextEditingController(
      text: restaurant['closingTime']?.toString() ?? defaultClosingTime,
    );

    var businessStatus = restaurant['businessStatus']?.toString() ?? 'open';

    const weeklyDays = <String, String>{
      'sat': 'السبت',
      'sun': 'الأحد',
      'mon': 'الاثنين',
      'tue': 'الثلاثاء',
      'wed': 'الأربعاء',
      'thu': 'الخميس',
      'fri': 'الجمعة',
    };

    final rawWeeklyHours = restaurant['weeklyHours'];
    final savedWeeklyHours = rawWeeklyHours is Map
        ? Map<String, dynamic>.from(rawWeeklyHours)
        : <String, dynamic>{};

    final weeklyOpenControllers = <String, TextEditingController>{};
    final weeklyCloseControllers = <String, TextEditingController>{};
    final weeklyClosed = <String, bool>{};

    for (final entry in weeklyDays.entries) {
      final rawDay = savedWeeklyHours[entry.key];
      final day = rawDay is Map
          ? Map<String, dynamic>.from(rawDay)
          : <String, dynamic>{};

      weeklyOpenControllers[entry.key] = TextEditingController(
        text: day['open']?.toString() ?? defaultOpeningTime,
      );
      weeklyCloseControllers[entry.key] = TextEditingController(
        text: day['close']?.toString() ?? defaultClosingTime,
      );
      weeklyClosed[entry.key] = day['closed'] == true;
    }

    var imageUrl = restaurant['image']?.toString() ?? '';
    File? selectedImage;
    var isSaving = false;
    var hasDeliveryOffer = restaurant['hasDeliveryOffer'] == true;
    var isTrending = restaurant['isTrending'] == true;
    double? latitude = (restaurant['latitude'] as num?)?.toDouble();
    double? longitude = (restaurant['longitude'] as num?)?.toDouble();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> chooseImage() async {
            try {
              final image = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (image != null) {
                setDialogState(() => selectedImage = File(image.path));
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذر اختيار الصورة.')),
                );
              }
            }
          }

          Future<void> saveRestaurant() async {
            final title = titleController.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('يرجى إدخال اسم ${widget.singularLabel}.')),
              );
              return;
            }
            setDialogState(() => isSaving = true);
            try {
              final commissionRate =
                  double.tryParse(commissionController.text.trim());
              if (commissionRate == null ||
                  commissionRate < 0 ||
                  commissionRate > 100) {
                throw StateError('أدخل نسبة عمولة صحيحة من 0 إلى 100.');
              }
              if (latitude == null || longitude == null) {
                throw StateError(
                  'يجب تحديد موقع ${widget.singularLabel} الحقيقي على الخريطة.',
                );
              }
              if (selectedImage != null) {
                imageUrl = await _uploadImage(selectedImage!);
              }
              final data = {
                'title': title,
                'description': descriptionController.text.trim(),
                'image': imageUrl,
                'category': categoryController.text.trim(),
                'type': typeController.text.trim().isEmpty
                    ? widget.itemType
                    : typeController.text.trim(),
                'rating': num.tryParse(ratingController.text.trim()) ?? 0,
                'discountPercent':
                    num.tryParse(discountController.text.trim()) ?? 0,
                'commissionRate': commissionRate,
                'hasDeliveryOffer': hasDeliveryOffer,
                'isTrending': isTrending,
                'businessStatus': businessStatus,
                'openingTime': openingTimeController.text.trim(),
                'closingTime': closingTimeController.text.trim(),
                'weeklyHours': {
                  for (final entry in weeklyDays.entries)
                    entry.key: {
                      'closed': weeklyClosed[entry.key] ?? false,
                      'open': weeklyOpenControllers[entry.key]!.text.trim(),
                      'close': weeklyCloseControllers[entry.key]!.text.trim(),
                    },
                },
                'preparationMinutes':
                    int.tryParse(preparationController.text.trim()) ?? 30,
                if (hasDeliveryOffer)
                  'deliveryFee':
                      num.tryParse(deliveryFeeController.text.trim()) ?? 0,
                'latitude': latitude,
                'longitude': longitude,
              };
              final ownerEmail = ownerEmailController.text.trim().toLowerCase();
              if (ownerEmail.isNotEmpty) {
                final ownerQuery = await _firestore
                    .collection('users')
                    .where('email', isEqualTo: ownerEmail)
                    .limit(1)
                    .get();
                if (ownerQuery.docs.isEmpty) {
                  throw StateError('يجب أن ينشئ صاحب المحل حساباً أولاً.');
                }
                final owner = ownerQuery.docs.first;
                data['ownerId'] = owner.id;
                data['ownerEmail'] = ownerEmail;
                await owner.reference.set(
                  {
                    if (owner.id != 'Y3YeLin9gYTbqN4if72o3iTrUSn2')
                      'role': 'merchant',
                  },
                  SetOptions(merge: true),
                );
              }
              if (doc == null) {
                await _firestore.collection('items').add(data);
              } else {
                await _firestore.collection('items').doc(doc.id).update(data);
              }
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error is StateError
                        ? error.message.toString()
                        : 'تعذر حفظ المطعم. حاول مرة أخرى.'),
                  ),
                );
              }
            } finally {
              if (context.mounted) setDialogState(() => isSaving = false);
            }
          }

          final preview = selectedImage != null
              ? Image.file(selectedImage!, fit: BoxFit.cover)
              : imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 42))
                  : const Icon(Icons.add_photo_alternate_outlined, size: 42);

          return AlertDialog(
            title: Text(doc == null
                ? 'إضافة ${widget.singularLabel}'
                : 'تعديل ${widget.singularLabel}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: isSaving ? null : chooseImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        preview,
                        Positioned(
                            bottom: 8,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Text(
                                  imageUrl.isEmpty && selectedImage == null
                                      ? 'اختيار صورة'
                                      : 'تغيير الصورة',
                                  style: const TextStyle(color: Colors.white)),
                            )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'اسم ${widget.singularLabel}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final location =
                                await Navigator.push<Map<String, double>>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LocationPickerScreen(
                                            latitude: latitude,
                                            longitude: longitude)));
                            if (location != null) {
                              setDialogState(() {
                                latitude = location['latitude'];
                                longitude = location['longitude'];
                              });
                            }
                          },
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(latitude == null
                        ? 'اختيار الموقع على الخريطة'
                        : 'تم اختيار الموقع — تغيير'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ratingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'التقييم من 5'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'خصم بركة % (اختياري)',
                        prefixIcon: Icon(Icons.percent_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commissionController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'نسبة عمولة بركة %',
                      helperText:
                          'تُحفظ مع كل طلب جديد لحماية الحسابات القديمة',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('عرض توصيل'),
                    subtitle: const Text('إظهار داخل خانة عروض التوصيل'),
                    value: hasDeliveryOffer,
                    onChanged: isSaving
                        ? null
                        : (value) =>
                            setDialogState(() => hasDeliveryOffer = value),
                  ),
                  if (hasDeliveryOffer) ...[
                    TextField(
                      controller: deliveryFeeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'سعر التوصيل بعد العرض (₪)',
                          prefixIcon: Icon(Icons.delivery_dining_rounded)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إظهار في قائمة الترندات'),
                    secondary: const Icon(Icons.local_fire_department_rounded,
                        color: Colors.orange),
                    value: isTrending,
                    onChanged: isSaving
                        ? null
                        : (value) => setDialogState(() => isTrending = value),
                  ),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'النوع',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'بريد صاحب المحل المشترك',
                      helperText:
                          'بعد الربط تظهر له لوحة إدارة منتجات محله فقط',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: preparationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة تجهيز الطلب بالدقائق',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'ساعات وحالة العمل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: openingTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'وقت الفتح',
                            hintText: '10:00',
                            prefixIcon: Icon(Icons.login_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: closingTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'وقت الإغلاق',
                            hintText: '03:00',
                            prefixIcon: Icon(Icons.logout_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'جدول أيام الأسبوع',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'يمكن تحديد وقت مختلف لكل يوم أو جعله عطلة.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final entry in weeklyDays.entries) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'عطلة',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Switch.adaptive(
                                value: weeklyClosed[entry.key] ?? false,
                                onChanged: isSaving
                                    ? null
                                    : (value) {
                                        setDialogState(() {
                                          weeklyClosed[entry.key] = value;
                                        });
                                      },
                              ),
                            ],
                          ),
                          if (!(weeklyClosed[entry.key] ?? false)) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        weeklyOpenControllers[entry.key],
                                    keyboardType: TextInputType.datetime,
                                    decoration: const InputDecoration(
                                      labelText: 'يفتح',
                                      hintText: '10:00',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        weeklyCloseControllers[entry.key],
                                    keyboardType: TextInputType.datetime,
                                    decoration: const InputDecoration(
                                      labelText: 'يغلق',
                                      hintText: '03:00',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: const ['open', 'busy', 'closed']
                            .contains(businessStatus)
                        ? businessStatus
                        : 'open',
                    decoration: const InputDecoration(
                      labelText: 'الحالة اليدوية',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'open',
                        child: Text('مفتوح — حسب ساعات العمل'),
                      ),
                      DropdownMenuItem(
                        value: 'busy',
                        child: Text('مشغول — يستقبل الطلبات'),
                      ),
                      DropdownMenuItem(
                        value: 'closed',
                        child: Text('مغلق مؤقتًا — لا يستقبل الطلبات'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => businessStatus = value);
                            }
                          },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : saveRestaurant,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          );
        });
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    typeController.dispose();
    ratingController.dispose();
    discountController.dispose();
    deliveryFeeController.dispose();
    openingTimeController.dispose();
    closingTimeController.dispose();
    for (final controller in weeklyOpenControllers.values) {
      controller.dispose();
    }
    for (final controller in weeklyCloseControllers.values) {
      controller.dispose();
    }
    commissionController.dispose();
    ownerEmailController.dispose();
    preparationController.dispose();
  }

  Future<void> _deleteRestaurant(String id) async {
    await _firestore.collection('items').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة ${widget.pluralLabel}'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRestaurantDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'لا يوجد ${widget.pluralLabel} حالياً',
                style: const TextStyle(fontSize: 18),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final restaurantDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] ?? '').toString().toLowerCase();
            return type == widget.itemType && data['kind'] != 'product';
          }).toList();

          if (restaurantDocs.isEmpty) {
            return Center(
              child: Text(
                'لا يوجد ${widget.pluralLabel} حالياً',
                style: const TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: restaurantDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = restaurantDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data['title'] ?? '').toString();
              final image = (data['image'] ?? '').toString();
              final description = (data['description'] ?? '').toString();
              final category = (data['category'] ?? '').toString();
              final type = (data['type'] ?? '').toString();
              final rating = (data['rating'] ?? 0).toString();
              final isTrending = data['isTrending'] == true;
              final ownerEmail = (data['ownerEmail'] ?? '').toString();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.coolYellow.withOpacity(0.25),
                        backgroundImage:
                            image.isNotEmpty ? NetworkImage(image) : null,
                        child: image.isEmpty
                            ? const Icon(Icons.storefront,
                                color: AppTheme.deepYellow)
                            : null,
                      ),
                      title: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        [
                          description,
                          category,
                          type,
                          '★ $rating',
                          ownerEmail.isEmpty
                              ? 'غير مفوّض لصاحب محل'
                              : 'مفوّض: $ownerEmail'
                        ].where((e) => e.isNotEmpty).join(' • '),
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'trend') {
                            doc.reference.update({'isTrending': !isTrending});
                          } else if (value == 'edit') {
                            _showRestaurantDialog(doc: doc);
                          } else if (value == 'delete') {
                            _deleteRestaurant(doc.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'trend',
                            child: Text(isTrending
                                ? 'إزالة من الترندات'
                                : 'إضافة إلى الترندات'),
                          ),
                          const PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل وربط صاحب المحل')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: Text('عرض وإضافة أصناف $title'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminManageProducts(
                                initialBusinessId: doc.id,
                                initialBusinessTitle: title,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
