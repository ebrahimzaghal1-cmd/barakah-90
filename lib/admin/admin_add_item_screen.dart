import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/location_picker_screen.dart';
import '../theme/app_theme.dart';
import '../services/user_profile_service.dart';

class AdminAddItemScreen extends StatefulWidget {
  const AdminAddItemScreen({
    super.key,
    this.initialType = 'restaurant',
    this.initialCategory,
  });

  final String initialType;
  final String? initialCategory;

  @override
  State<AdminAddItemScreen> createState() => _AdminAddItemScreenState();
}

class _AdminAddItemScreenState extends State<AdminAddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController ratingController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController deliveryFeeController = TextEditingController();
  final TextEditingController ownerEmailController = TextEditingController();
  final TextEditingController agentPhoneController = TextEditingController();
  final TextEditingController agentLocationController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController preparationController =
      TextEditingController(text: '30');
  final ImagePicker _imagePicker = ImagePicker();

  String selectedType = 'restaurant';
  String? selectedCategory;
  bool isLoading = false;
  bool hasDeliveryOffer = false;
  bool isTrending = false;
  File? selectedImage;
  double? latitude;
  double? longitude;

  bool get _isAgentCategory {
    final category =
        (selectedCategory ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return category.contains('وسيط') || category.contains('وسطاء');
  }

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    ratingController.dispose();
    discountController.dispose();
    deliveryFeeController.dispose();
    ownerEmailController.dispose();
    agentPhoneController.dispose();
    agentLocationController.dispose();
    facebookController.dispose();
    instagramController.dispose();
    whatsappController.dispose();
    websiteController.dispose();
    preparationController.dispose();
    super.dispose();
  }

  Future<String> _uploadImage(File image) async {
    final request = http.MultipartRequest('POST',
        Uri.parse('https://barakah-90-production-384c.up.railway.app/upload'));
    request.files.add(await http.MultipartFile.fromPath('image', image.path,
        contentType: MediaType('image', 'jpeg')));
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Image upload failed');
    final json = jsonDecode(await response.stream.bytesToString())
        as Map<String, dynamic>;
    final imageUrl = json['url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Image upload returned no URL');
    }
    return imageUrl;
  }

  Future<void> _chooseImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => selectedImage = File(image.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر اختيار الصورة.')),
        );
      }
    }
  }

  Future<void> saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار صورة.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final ownerEmail = ownerEmailController.text.trim().toLowerCase();
      DocumentSnapshot<Map<String, dynamic>>? owner;
      if (ownerEmail.isNotEmpty) {
        final ownerQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: ownerEmail)
            .limit(1)
            .get();
        if (ownerQuery.docs.isEmpty) {
          throw StateError(
              'لا يوجد حساب بهذا البريد. يجب أن يسجل صاحب المحل حسابًا أولاً.');
        }
        owner = ownerQuery.docs.first;
        if (owner.data()?['role']?.toString() == 'admin') {
          throw StateError('لا يمكن تحويل حساب الأدمن إلى حساب صاحب محل.');
        }
      }

      final imageUrl = await _uploadImage(selectedImage!);
      final businessRef = firestore.collection('items').doc();
      final batch = firestore.batch();
      batch.set(businessRef, {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'image': imageUrl,
        'category': selectedCategory ?? '',
        'type': selectedType,
        // هذا سجل محل/مطعم. الأسعار تخص منتجاته فقط ولا تحفظ هنا.
        'kind': _isAgentCategory ? 'agent' : 'business',
        'rating': num.tryParse(ratingController.text.trim()) ?? 0,
        'discountPercent': num.tryParse(discountController.text.trim()) ?? 0,
        'hasDeliveryOffer': hasDeliveryOffer,
        'isTrending': isTrending,
        'businessStatus': 'open',
        'preparationMinutes':
            int.tryParse(preparationController.text.trim()) ?? 30,
        if (hasDeliveryOffer)
          'deliveryFee': num.tryParse(deliveryFeeController.text.trim()) ?? 0,
        'createdAt': Timestamp.now(),
        if (latitude != null && longitude != null) 'latitude': latitude,
        if (latitude != null && longitude != null) 'longitude': longitude,
        if (_isAgentCategory) 'agentPhone': agentPhoneController.text.trim(),
        if (_isAgentCategory)
          'agentLocation': agentLocationController.text.trim(),
        if (_isAgentCategory) 'facebookUrl': facebookController.text.trim(),
        if (_isAgentCategory) 'instagramUrl': instagramController.text.trim(),
        if (_isAgentCategory) 'whatsappUrl': whatsappController.text.trim(),
        if (_isAgentCategory) 'websiteUrl': websiteController.text.trim(),
        if (owner != null) 'ownerId': owner.id,
        if (owner != null) 'ownerEmail': ownerEmail,
      });
      if (owner != null) {
        batch.set(
          owner.reference,
          {
            if (owner.id != 'Y3YeLin9gYTbqN4if72o3iTrUSn2') 'role': 'merchant',
            'merchantEnabled': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الإضافة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      titleController.clear();
      descriptionController.clear();
      ratingController.clear();
      discountController.clear();
      deliveryFeeController.clear();
      ownerEmailController.clear();
      agentPhoneController.clear();
      agentLocationController.clear();
      facebookController.clear();
      instagramController.clear();
      whatsappController.clear();
      websiteController.clear();

      setState(() {
        selectedType = 'restaurant';
        selectedCategory = null;
        selectedImage = null;
        latitude = null;
        longitude = null;
        hasDeliveryOffer = false;
        isTrending = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError
              ? e.message.toString()
              : 'تعذر حفظ المحل. تحققي من البيانات وحاولي مجددًا.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<bool>(
      future: user == null
          ? Future.value(false)
          : UserProfileService().isAdmin(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('صلاحيات الأدمن')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('إضافة المطاعم والمحلات متاحة للأدمن فقط.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }
        return _buildAddScreen(context);
      },
    );
  }

  Widget _buildAddScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إضافة مطعم / متجر',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'restaurant',
                      child: Text('مطعم'),
                    ),
                    DropdownMenuItem(
                      value: 'market',
                      child: Text('ماركت'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                        selectedCategory = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخلي الاسم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخلي الوصف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _CategoryPicker(
                  collectionName: selectedType == 'market'
                      ? 'market_categories'
                      : 'restaurant_categories',
                  value: selectedCategory,
                  onChanged: (value) =>
                      setState(() => selectedCategory = value),
                ),
                if (_isAgentCategory) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: agentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الوسيط أو الوسيطة',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (value) => _isAgentCategory &&
                            (value == null || value.trim().isEmpty)
                        ? 'أدخلي رقم الوسيطة'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: agentLocationController,
                    decoration: InputDecoration(
                      labelText: 'عنوان أو منطقة الوسيطة',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: whatsappController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'رابط واتساب',
                      prefixIcon: const Icon(Icons.chat_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: instagramController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'رابط إنستغرام',
                      prefixIcon: const Icon(Icons.camera_alt_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: facebookController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'رابط فيسبوك',
                      prefixIcon: const Icon(Icons.facebook_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: websiteController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'رابط الصفحة أو الموقع',
                      prefixIcon: const Icon(Icons.link_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.coolYellow.withOpacity(.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تفويض صاحب المحل',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'يسجل صاحب المحل حسابًا عاديًا أولاً، ثم تربطينه هنا. بعدها يشاهد محله ومنتجاته وطلباته فقط.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'بريد حساب صاحب المحل',
                          hintText: 'example@gmail.com',
                          prefixIcon:
                              const Icon(Icons.manage_accounts_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          helperText: 'يمكن تركه فارغًا وربط صاحب المحل لاحقًا',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            return 'أدخلي بريدًا إلكترونيًا صحيحًا';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: preparationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'مدة تجهيز الطلب الافتراضية بالدقائق',
                    prefixIcon: const Icon(Icons.timer_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ratingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'التقييم من 5',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'خصم بركة % (اختياري)',
                    prefixIcon: const Icon(Icons.percent_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إضافة المطعم إلى عروض التوصيل'),
                  subtitle: const Text('يظهر داخل خانة عروض التوصيل'),
                  value: hasDeliveryOffer,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => hasDeliveryOffer = value),
                ),
                if (hasDeliveryOffer) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: deliveryFeeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'سعر التوصيل بعد العرض (₪)',
                      prefixIcon: const Icon(Icons.delivery_dining_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إظهار في قائمة الترندات'),
                  subtitle: const Text('يمكن تغييره لاحقًا من إدارة المطاعم'),
                  secondary: const Icon(Icons.local_fire_department_rounded,
                      color: Colors.orange),
                  value: isTrending,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => isTrending = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(latitude == null
                      ? 'اختيار موقع المتجر على الخريطة'
                      : 'تم اختيار الموقع — تغيير'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final location =
                              await Navigator.push<Map<String, double>>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                          latitude: latitude,
                                          longitude: longitude)));
                          if (location != null && mounted) {
                            setState(() {
                              latitude = location['latitude'];
                              longitude = location['longitude'];
                            });
                          }
                        },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: isLoading ? null : _chooseImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 42),
                                SizedBox(height: 8),
                                Text('اختيار صورة'),
                              ])
                        : Image.file(selectedImage!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : saveItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.collectionName,
    required this.value,
    required this.onChanged,
  });

  final String collectionName;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection(collectionName).snapshots(),
        builder: (context, snapshot) {
          final names = (snapshot.data?.docs ?? [])
              .map((doc) => doc.data()['title']?.toString().trim() ?? '')
              .where((title) => title.isNotEmpty)
              .toSet()
              .toList();
          if (names.isEmpty) {
            names.addAll(collectionName == 'market_categories'
                ? const [
                    'مخبوزات',
                    'دجاج',
                    'أسماك',
                    'خضار وفواكه',
                    'لحوم',
                    'صيدلية',
                    'سوبرماركت',
                  ]
                : const [
                    'مشاوي',
                    'برغر',
                    'دجاج',
                    'بيتزا',
                    'شاورما',
                    'قهوة وحلويات',
                  ]);
          }
          return DropdownButtonFormField<String>(
            value: names.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: collectionName == 'market_categories'
                  ? 'القسم الذي سيظهر داخله المحل'
                  : 'القسم الذي سيظهر داخله المطعم',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            hint: const Text('اختر من الأقسام الموجودة'),
            items: names
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: names.isEmpty ? null : onChanged,
            validator: (selected) => selected == null || selected.isEmpty
                ? 'اختر القسم الذي تريد وضع المحل داخله'
                : null,
          );
        },
      );
}
