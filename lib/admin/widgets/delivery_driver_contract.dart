import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../screens/legal_documents_screen.dart';
import '../../utils/pdf_download_stub.dart'
    if (dart.library.js_interop) '../../utils/pdf_download_web.dart';

// Base64 and metadata must fit within Firestore's document size limit.
const maxDeliveryContractBytes = 600 * 1024;

void validateDeliveryContract(Uint8List bytes) {
  if (bytes.length > maxDeliveryContractBytes) {
    throw StateError('حجم عقد PDF يجب ألا يتجاوز 600KB.');
  }
  if (bytes.length < 5 ||
      ascii.decode(bytes.sublist(0, 5), allowInvalid: true) != '%PDF-') {
    throw StateError('اختر ملف PDF صالحًا للعقد.');
  }
}

class DeliveryDriverContract extends StatefulWidget {
  const DeliveryDriverContract({super.key, required this.application});
  final DocumentSnapshot<Map<String, dynamic>> application;

  @override
  State<DeliveryDriverContract> createState() => _DeliveryDriverContractState();
}

class _DeliveryDriverContractState extends State<DeliveryDriverContract> {
  bool busy = false;
  Map<String, dynamic> get data => widget.application.data() ?? {};

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Uint8List> generate() async {
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final document = pw.Document();
    final terms = const LegalDocumentScreen(type: LegalDocumentType.driverTerms)
        .sections
        .where((section) => !section.$1.contains('التكسي'));
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Text('عقد انضمام سائق توصيل إلى بركة',
            style: const pw.TextStyle(fontSize: 20)),
        pw.SizedBox(height: 14),
        for (final field in <(String, String)>[
          ('اسم السائق', 'fullName'),
          ('البريد الإلكتروني', 'email'),
          ('رقم الهاتف', 'phone'),
          ('رقم الهوية', 'nationalId'),
          ('المركبة', 'vehicle'),
          ('رخصة القيادة', 'driverLicenseNumber'),
          ('رخصة المركبة', 'vehicleLicenseNumber'),
          ('التأمين', 'vehicleInsuranceNumber'),
          ('طريقة استلام المستحقات', 'payoutMethod'),
          ('حساب المستحقات', 'payoutAccount'),
          ('إصدار الشروط المقبول', 'agreementVersion'),
        ])
          pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${field.$1}: ${data[field.$2] ?? '—'}')),
        pw.Text(
            'حالة الطلب: ${data['status'] == 'approved' ? 'معتمد' : 'بانتظار الاعتماد'}'),
        pw.Text(
            'موافقة السائق على الشروط: ${data['acceptedDriverTerms'] == true ? 'نعم' : 'لا'}'),
        pw.SizedBox(height: 14),
        for (final section in terms) ...[
          pw.Text(section.$1, style: const pw.TextStyle(fontSize: 13)),
          pw.Text(section.$2),
          pw.SizedBox(height: 8),
        ],
        pw.SizedBox(height: 20),
        pw.Text('توقيع السائق: ____________________'),
        pw.Text('توقيع إدارة بركة: ____________________'),
        pw.Text('التاريخ: ____________________'),
      ],
    ));
    return document.save();
  }

  Future<void> download(Uint8List bytes, String name) async {
    if (kIsWeb) {
      await downloadPdfBytes(bytes, name);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: name);
    }
  }

  Future<void> upload() async {
    const group = XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    if (await file.length() > maxDeliveryContractBytes) {
      throw StateError('حجم عقد PDF يجب ألا يتجاوز 600KB.');
    }
    final bytes = await file.readAsBytes();
    validateDeliveryContract(bytes);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('سجّل الدخول بحساب الأدمن.');
    await widget.application.reference.update({
      'deliveryContract': {
        'name': file.name,
        'dataBase64': base64Encode(bytes),
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': user.uid,
      },
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ نسخة العقد الموقعة ✅')));
    }
  }

  Uint8List signedBytes() {
    final contract = data['deliveryContract'];
    if (contract is! Map || contract['dataBase64'] is! String) {
      throw StateError('لم تُرفع نسخة موقعة بعد.');
    }
    final bytes = base64Decode(contract['dataBase64'] as String);
    validateDeliveryContract(bytes);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final hasSigned = data['deliveryContract'] is Map &&
        (data['deliveryContract'] as Map)['dataBase64'] is String;
    final filename = 'barakah_delivery_contract_${widget.application.id}.pdf';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('عقد سائق التوصيل',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                            final bytes = await generate();
                            await Printing.layoutPdf(
                                name: filename, onLayout: (_) async => bytes);
                          }),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة العقد')),
              OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                            await download(await generate(), filename);
                          }),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('تنزيل عقد PDF')),
              OutlinedButton.icon(
                  onPressed: busy ? null : () => run(upload),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(hasSigned
                      ? 'استبدال العقد الموقّع'
                      : 'رفع العقد الموقّع')),
              const Text('PDF حتى 600KB',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              if (hasSigned) ...[
                const Text('النسخة الموقّعة محفوظة',
                    style: TextStyle(color: Color(0xFF1B8A5A))),
                OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              await download(signedBytes(), 'signed_$filename');
                            }),
                    icon: const Icon(Icons.download_done),
                    label: const Text('تنزيل العقد الموقّع')),
                OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              final bytes = signedBytes();
                              await Printing.layoutPdf(
                                  name: 'signed_$filename',
                                  onLayout: (_) async => bytes);
                            }),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('طباعة العقد الموقّع')),
              ],
              if (busy) const LinearProgressIndicator(),
            ],
          )),
    );
  }
}
