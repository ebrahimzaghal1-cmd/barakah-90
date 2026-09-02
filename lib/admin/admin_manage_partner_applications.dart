import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import 'admin_activate_partner_screen.dart';
import '../utils/pdf_download_stub.dart'
    if (dart.library.js_interop) '../utils/pdf_download_web.dart';

class AdminManagePartnerApplications extends StatelessWidget {
  const AdminManagePartnerApplications({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'بانتظار المراجعة';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF1B8A5A);
      case 'rejected':
        return const Color(0xFFC0392B);
      default:
        return const Color(0xFF9A6A00);
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    String applicationId,
    String status,
  ) async {
    final isApprove = status == 'approved';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isApprove ? 'قبول طلب الشريك' : 'رفض طلب الشريك'),
        content: Text(
          isApprove
              ? 'هل تريد قبول طلب انضمام هذا المطعم / المتجر؟'
              : 'هل تريد رفض طلب الانضمام؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isApprove ? 'قبول' : 'رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('merchant_applications')
          .doc(applicationId)
          .update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApprove ? 'تم قبول طلب الشريك ✅' : 'تم رفض طلب الشريك',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديث الطلب الآن.'),
        ),
      );
    }
  }

  void _showDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    String value(String key) {
      final result = data[key]?.toString().trim() ?? '';
      return result.isEmpty ? 'غير مضاف' : result;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تفاصيل طلب الشريك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.storefront_rounded,
                label: 'اسم المحل',
                value: value('businessName'),
              ),
              _DetailRow(
                icon: Icons.person_rounded,
                label: 'اسم المسؤول',
                value: value('ownerName'),
              ),
              _DetailRow(
                icon: Icons.phone_rounded,
                label: 'رقم الهاتف',
                value: value('phone'),
              ),
              _DetailRow(
                icon: Icons.category_rounded,
                label: 'نوع النشاط',
                value: value('activityType'),
              ),
              _DetailRow(
                icon: Icons.category_outlined,
                label: 'القسم المطلوب',
                value: value('businessCategory'),
              ),
              _DetailRow(
                icon: Icons.location_on_rounded,
                label: 'المنطقة',
                value: value('area'),
              ),
              _DetailRow(
                icon: Icons.notes_rounded,
                label: 'الوصف',
                value: value('description'),
              ),
              _DetailRow(
                icon: Icons.map_rounded,
                label: 'رابط الموقع',
                value: value('locationUrl'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editApplication(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> data,
  ) async {
    final businessName = TextEditingController(
      text: data['businessName']?.toString() ?? '',
    );
    final ownerName = TextEditingController(
      text: data['ownerName']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: data['phone']?.toString() ?? '',
    );
    final activityType = TextEditingController(
      text: data['activityType']?.toString() ?? '',
    );
    final businessCategory = TextEditingController(
      text: data['businessCategory']?.toString() ?? '',
    );
    final area = TextEditingController(
      text: data['area']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    final locationUrl = TextEditingController(
      text: data['locationUrl']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تعديل بيانات المتجر',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: businessName,
                decoration: const InputDecoration(
                  labelText: 'اسم المحل',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ownerName,
                decoration: const InputDecoration(
                  labelText: 'اسم المسؤول',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: activityType,
                decoration: const InputDecoration(
                  labelText: 'نوع النشاط',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: businessCategory,
                decoration: const InputDecoration(
                  labelText: 'القسم المطلوب',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: area,
                decoration: const InputDecoration(
                  labelText: 'المنطقة',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationUrl,
                decoration: const InputDecoration(
                  labelText: 'رابط الموقع',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );

    if (saved != true) {
      businessName.dispose();
      ownerName.dispose();
      phone.dispose();
      activityType.dispose();
      businessCategory.dispose();
      area.dispose();
      description.dispose();
      locationUrl.dispose();
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final category = businessCategory.text.trim();
      final activity = activityType.text.trim();
      final merchantType = _merchantTypeFromActivity(activity);

      final businessId = data['businessId']?.toString().trim() ?? '';

      final linkedUserId = data['linkedUserId']?.toString().trim() ?? '';

      final batch = firestore.batch();

      batch.set(
        firestore.collection('merchant_applications').doc(applicationId),
        {
          'businessName': businessName.text.trim(),
          'ownerName': ownerName.text.trim(),
          'phone': phone.text.trim(),
          'activityType': activity,
          'businessCategory': category,
          'approvedCategory': category,
          'approvedMerchantType': merchantType,
          'area': area.text.trim(),
          'description': description.text.trim(),
          'locationUrl': locationUrl.text.trim(),
          if (merchantType == 'barber') ...{
            'appointmentBookingEnabled': true,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (businessId.isNotEmpty) {
        batch.set(
          firestore.collection('items').doc(businessId),
          {
            'category': category,
            'type': merchantType,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (linkedUserId.isNotEmpty) {
        batch.set(
          firestore.collection('users').doc(linkedUserId),
          {
            'merchantCategory': category,
            'merchantType': merchantType,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعديل بيانات المتجر ✅'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تعديل بيانات المتجر.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      businessName.dispose();
      ownerName.dispose();
      phone.dispose();
      activityType.dispose();
      businessCategory.dispose();
      area.dispose();
      description.dispose();
      locationUrl.dispose();
    }
  }

  String _merchantTypeFromActivity(String activity) {
    final value = activity.trim();

    if (value == 'حلاق' || value == 'صالون' || value == 'barber') {
      return 'barber';
    }
    if (value == 'طبيب' || value == 'دكتور' || value == 'doctor') {
      return 'doctor';
    }

    const restaurantTypes = <String>{
      'مطاعم',
      'مطعم',
      'حلويات',
      'مخبوزات',
      'مخابز',
      'عصائر',
      'قهوة',
      'كافيه',
      'كافيهات',
      'وجبات سريعة',
    };

    return restaurantTypes.contains(value) ? 'restaurant' : 'market';
  }

  Future<void> _restoreMissingBusiness(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> data,
  ) async {
    final businessId = data['businessId']?.toString().trim() ?? '';
    final ownerId = data['linkedUserId']?.toString().trim() ?? '';
    final businessName = data['businessName']?.toString().trim() ?? '';

    final businessCategory =
        data['businessCategory']?.toString().trim().isNotEmpty == true
            ? data['businessCategory'].toString().trim()
            : data['approvedCategory']?.toString().trim() ?? '';

    final activityType = data['activityType']?.toString().trim() ?? '';

    if (businessId.isEmpty || ownerId.isEmpty || businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن استعادة المتجر لأن رقم المتجر أو حساب المالك أو اسم المتجر غير محفوظ.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (businessCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حددي القسم المطلوب في بيانات طلب الشريك أولًا.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'استعادة المتجر المرتبط',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'سيتم إعادة إنشاء متجر "$businessName" بنفس رقم المتجر القديم:\n\n'
          '$businessId\n\n'
          'المنتجات القديمة المرتبطة بهذا الرقم ستعود تلقائيًا.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة المتجر'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final businessRef = firestore.collection('items').doc(businessId);

      final existing = await businessRef.get();

      if (existing.exists) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'المتجر موجود بالفعل ولا يحتاج إلى استعادة.',
            ),
          ),
        );
        return;
      }

      final commissionRate = data['commissionRate'] is num
          ? (data['commissionRate'] as num).toDouble()
          : double.tryParse(
                data['commissionRate']?.toString() ?? '',
              ) ??
              10.0;

      final approvedType =
          data['approvedMerchantType']?.toString().trim() ?? '';

      final type = approvedType.isNotEmpty
          ? approvedType
          : _merchantTypeFromActivity(activityType);

      final batch = firestore.batch();

      batch.set(
        businessRef,
        {
          'title': businessName,
          'description': data['description']?.toString().trim() ?? '',
          'phone': data['phone']?.toString().trim() ?? '',
          'address': data['area']?.toString().trim() ?? '',
          if (data['latitude'] != null) 'latitude': data['latitude'],
          if (data['longitude'] != null) 'longitude': data['longitude'],
          'category': businessCategory,
          'type': type,
          'kind': 'business',
          'rating': 0,
          'discountPercent': 0,
          'commissionRate': commissionRate,
          'hasDeliveryOffer': false,
          'isTrending': false,
          'businessStatus': 'open',
          'openingTime': type == 'barber'
              ? (data['barberOpeningTime']?.toString().trim().isNotEmpty == true
                  ? data['barberOpeningTime'].toString().trim()
                  : '09:00')
              : type == 'doctor'
                  ? '09:00'
                  : type == 'market'
                      ? '10:00'
                      : '08:00',
          'closingTime': type == 'barber'
              ? (data['barberClosingTime']?.toString().trim().isNotEmpty == true
                  ? data['barberClosingTime'].toString().trim()
                  : '21:00')
              : type == 'doctor'
                  ? '17:00'
                  : type == 'market'
                      ? '03:00'
                      : '23:00',
          'preparationMinutes': 30,
          if (type == 'barber') ...{
            'barberServices': data['barberServices'] is List
                ? data['barberServices']
                : const <Map<String, dynamic>>[],
            'appointmentSlotMinutes':
                int.tryParse(data['barberSlotMinutes']?.toString() ?? '') ?? 30,
            'appointmentBookingEnabled': true,
          },
          if (type == 'doctor') ...{
            'doctorSpecialty': data['doctorSpecialty']?.toString().trim() ?? '',
            'doctorLicense': data['doctorLicense']?.toString().trim() ?? '',
            'consultationFee': data['doctorConsultationFee'] ?? 0,
            'appointmentBookingEnabled': true,
          },
          'ownerId': ownerId,
          'ownerEmail': data['email']?.toString().trim() ?? '',
          'partnerApplicationId': applicationId,
          'createdAt': FieldValue.serverTimestamp(),
          'restoredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        firestore.collection('users').doc(ownerId),
        {
          'merchantEnabled': true,
          'merchantBusinessId': businessId,
          'merchantBusinessName': businessName,
          'merchantCategory': businessCategory,
          'merchantType': type,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        firestore.collection('merchant_applications').doc(applicationId),
        {
          'businessId': businessId,
          'approvedCategory': businessCategory,
          'approvedMerchantType': type,
          'merchantEnabled': true,
          'restoredBusinessAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت استعادة متجر $businessName وربط المنتجات القديمة به ✅',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر استعادة المتجر: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteApplication(
    BuildContext context,
    String applicationId,
    String businessName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'إزالة المتجر',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل تريد حذف طلب ومتجر "$businessName" من قائمة الشركاء؟\n\nهذا الإجراء لا يمكن التراجع عنه.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('merchant_applications')
          .doc(applicationId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إزالة المتجر'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إزالة المتجر.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadPartnerContractPdf(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> application,
  ) async {
    final data = application.data() ?? <String, dynamic>{};

    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final arabicFont = pw.Font.ttf(fontData);
      final document = pw.Document();
      final generatedAt = DateTime.now();

      String valueOf(String key, [String fallback = '—']) {
        final value = data[key];
        if (value == null) return fallback;
        final text = value.toString().trim();
        return text.isEmpty ? fallback : text;
      }

      String yesNo(String key) => data[key] == true ? 'نعم' : 'لا';

      final privacyText = valueOf(
        'privacyPolicyText',
        'وافق الشريك إلكترونيًا على سياسة الخصوصية المعتمدة في بركة وفق الإصدار المحفوظ مع الطلب.',
      );

      final termsText = valueOf(
        'partnerTermsText',
        'وافق الشريك إلكترونيًا على اتفاقية وشروط الانضمام المعتمدة في بركة وفق الإصدار المحفوظ مع الطلب.',
      );

      pw.Widget field(String label, Object? value) {
        final text = value?.toString().trim() ?? '';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  text.isEmpty ? '—' : text,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: arabicFont, fontSize: 11),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                '$label:',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

      pw.Widget sectionTitle(String title) => pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#12284C'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              title,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicFont,
          ),
          build: (pdfContext) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#12284C'),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#D4AF37'),
                        width: 1.5,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          'BARAKAH | بركة',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'عقد وطلب انضمام شريك',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 14,
                            color: PdfColor.fromHex('#D4AF37'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  field('رقم الطلب', application.id),
                  field('اسم المطعم / المحل', valueOf('businessName')),
                  field('اسم المسؤول', valueOf('ownerName')),
                  field('البريد الإلكتروني', valueOf('email')),
                  field('رقم الهاتف', valueOf('phone')),
                  field('رقم الهوية', valueOf('nationalId')),
                  field('نوع النشاط', valueOf('activityType')),
                  field('القسم', valueOf('businessCategory')),
                  field('المدينة / المنطقة', valueOf('area')),
                  field('رابط موقع Google Maps', valueOf('locationUrl')),
                  field('خط العرض', valueOf('latitude')),
                  field('خط الطول', valueOf('longitude')),
                  field('إصدار الاتفاقية', valueOf('agreementVersion')),
                  field(
                    'الموافقة على سياسة الخصوصية',
                    yesNo('acceptedPrivacyPolicy'),
                  ),
                  field(
                    'الموافقة على اتفاقية الشريك',
                    yesNo('acceptedPartnerAgreement'),
                  ),
                  field('حالة الطلب', valueOf('status')),
                  field(
                    'تاريخ إنشاء نسخة PDF',
                    '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
                        '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  sectionTitle('سياسة الخصوصية'),
                  pw.Text(
                    privacyText,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 10.5,
                      lineSpacing: 4,
                    ),
                  ),
                  sectionTitle('شروط الانضمام كشريك في بركة'),
                  pw.Text(
                    termsText,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 10.5,
                      lineSpacing: 4,
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Divider(
                    color: PdfColor.fromHex('#D4AF37'),
                  ),
                  pw.Text(
                    'هذه النسخة مرتبطة بطلب الشريك رقم ${application.id} ومحفوظة لأغراض السجل الإداري في بركة.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await document.save();
      final filename = 'barakah_partner_contract_${application.id}.pdf';

      if (kIsWeb) {
        await downloadPdfBytes(bytes, filename);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء عقد PDF: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'طلبات انضمام الشركاء',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('merchant_applications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل طلبات الشركاء.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final applications = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final left = a.data()['createdAt'] as Timestamp?;
              final right = b.data()['createdAt'] as Timestamp?;

              return (right?.millisecondsSinceEpoch ?? 0)
                  .compareTo(left?.millisecondsSinceEpoch ?? 0);
            });

          if (applications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 72,
                      color: AppTheme.coolYellow,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات انضمام حاليًا',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = applications[index];
              final data = doc.data();

              final businessName =
                  data['businessName']?.toString().trim() ?? 'محل بدون اسم';

              final ownerName = data['ownerName']?.toString().trim() ?? '';

              final phone = data['phone']?.toString().trim() ?? '';

              final activity = data['activityType']?.toString().trim() ?? '';

              final area = data['area']?.toString().trim() ?? '';

              final status = data['status']?.toString().trim() ?? 'pending';

              final pending = status == 'pending';

              final linkedUserId =
                  data['linkedUserId']?.toString().trim() ?? '';

              final needsMerchantActivation =
                  status == 'approved' && linkedUserId.isEmpty;

              return Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.coolYellow.withOpacity(.24),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppTheme.navy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  businessName,
                                  style: const TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (activity.isNotEmpty || area.isNotEmpty)
                                  Text(
                                    [
                                      if (activity.isNotEmpty) activity,
                                      if (area.isNotEmpty) area,
                                    ].join(' • '),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (ownerName.isNotEmpty)
                        Text(
                          'المسؤول: $ownerName',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الهاتف: $phone',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _showDetails(context, data),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('عرض التفاصيل'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _downloadPartnerContractPdf(context, doc),
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('تحميل عقد PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF12284C),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editApplication(
                                context,
                                doc.id,
                                data,
                              ),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('تعديل'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteApplication(
                                context,
                                doc.id,
                                businessName,
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('إزالة المتجر'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((data['status']?.toString() == 'approved') &&
                          (data['businessId']?.toString().trim().isNotEmpty ==
                              true) &&
                          (data['linkedUserId']?.toString().trim().isNotEmpty ==
                              true)) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _restoreMissingBusiness(
                              context,
                              doc.id,
                              data,
                            ),
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text(
                              'استعادة المتجر المرتبط',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navy,
                            ),
                          ),
                        ),
                      ],
                      if (needsMerchantActivation) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminActivatePartnerScreen(
                                    applicationId: doc.id,
                                    application: data,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.verified_user_rounded,
                            ),
                            label: const Text(
                              'تفعيل حساب التاجر',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.navy,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (pending) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminActivatePartnerScreen(
                                        applicationId: doc.id,
                                        application: data,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('قبول'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B8A5A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _changeStatus(
                                  context,
                                  doc.id,
                                  'rejected',
                                ),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('رفض'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.deepYellow,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
