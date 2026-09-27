import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/admin_agent_pdf_download.dart';

class AdminAgentContractPanel extends StatefulWidget {
  final String agentId;
  final String agentName;

  const AdminAgentContractPanel({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<AdminAgentContractPanel> createState() =>
      _AdminAgentContractPanelState();
}

class _AdminAgentContractPanelState extends State<AdminAgentContractPanel> {
  bool _busy = false;

  DocumentReference<Map<String, dynamic>> get _agentRef =>
      FirebaseFirestore.instance.collection('agents').doc(widget.agentId);

  String get _storagePath => 'agent_contracts/${widget.agentId}/contract.pdf';

  String _first(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '—',
  }) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return fallback;
  }

  String _fileName(Map<String, dynamic> data) {
    final value = data['contractFileName']?.toString().trim() ?? '';
    return value.isEmpty ? 'contract.pdf' : value;
  }

  String _status(Map<String, dynamic> data) {
    return data['contractStatus']?.toString() ?? 'missing';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'النسخة الموقعة معتمدة';
      case 'uploaded':
        return 'النسخة الموقعة بانتظار الاعتماد';
      default:
        return 'لم تُرفع النسخة الموقعة';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF138A5B);
      case 'uploaded':
        return const Color(0xFFD18B00);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '—';

    final d = value.toDate().toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  Future<Map<String, dynamic>> _loadContractData(
    Map<String, dynamic> agentData,
  ) async {
    Map<String, dynamic> applicationData = const {};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('agent_applications')
          .doc(widget.agentId)
          .get();

      applicationData = snapshot.data() ?? const {};
    } catch (_) {}

    // بيانات الملف الداخلي الأحدث لها الأولوية،
    // وطلب الانضمام يكمل بيانات الاتفاقية الأصلية.
    return <String, dynamic>{
      ...applicationData,
      ...agentData,
    };
  }

  Future<Uint8List> _buildAgentContractPdf(
    Map<String, dynamic> agentData,
  ) async {
    final data = await _loadContractData(agentData);

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');

    final arabicFont = pw.Font.ttf(fontData);
    final document = pw.Document();
    final generatedAt = DateTime.now();

    String valueOf(
      String key, [
      String fallback = '—',
    ]) {
      final value = data[key];

      if (value == null) return fallback;

      final text = value.toString().trim();

      return text.isEmpty ? fallback : text;
    }

    String yesNo(String key) => data[key] == true ? 'نعم' : 'لا';

    final privacyText = valueOf(
      'privacyPolicyText',
      'وافقت الوسيطة إلكترونيًا على سياسة الخصوصية '
          'المعتمدة في بركة وفق الإصدار المحفوظ مع طلب الانضمام.',
    );

    final termsText = valueOf(
      'agentTermsText',
      'وافقت الوسيطة إلكترونيًا على شروط الانضمام '
          'كوسيطة في بركة وفق الإصدار المحفوظ مع الطلب. '
          'هذه النسخة مخصصة للطباعة والتوقيع، ولا تعتبر النسخة '
          'الموقعة معتمدة نهائيًا إلا بعد رفعها ومراجعتها واعتمادها '
          'من إدارة بركة.',
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
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                ),
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

    pw.Widget sectionTitle(String title) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(
          top: 12,
          bottom: 8,
        ),
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
    }

    pw.Widget signatureBox(String title) {
      return pw.Container(
        height: 85,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColor.fromHex('#CBD5E1'),
          ),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              title,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              'التوقيع: ________________________',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

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
                        'عقد وطلب انضمام وسيطة',
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
                field('معرف الوسيطة', widget.agentId),
                field(
                  'الاسم الكامل',
                  _first(
                    data,
                    ['fullName', 'name'],
                    fallback: widget.agentName,
                  ),
                ),
                field('البريد الإلكتروني', valueOf('email')),
                field('رقم الهاتف', valueOf('phone')),
                field('رقم الهوية', valueOf('nationalId')),
                field('المدينة / المنطقة', valueOf('area')),
                field(
                  'وصف الموقع',
                  _first(
                    data,
                    ['locationLabel', 'location'],
                  ),
                ),
                field('خط العرض', valueOf('latitude')),
                field('خط الطول', valueOf('longitude')),
                field(
                  'طريقة استلام المستحقات',
                  valueOf('payoutMethod'),
                ),
                field(
                  'بيانات استلام المستحقات',
                  valueOf('payoutAccount'),
                ),
                field(
                  'إصدار الاتفاقية',
                  valueOf('agreementVersion'),
                ),
                field(
                  'الموافقة على سياسة الخصوصية',
                  yesNo('acceptedPrivacyPolicy'),
                ),
                field(
                  'الموافقة على شروط الوسيطة',
                  yesNo('acceptedAgentTerms'),
                ),
                field(
                  'حالة طلب الانضمام',
                  valueOf('status', 'approved'),
                ),
                field(
                  'تاريخ إنشاء نسخة PDF',
                  '${generatedAt.year}-'
                      '${generatedAt.month.toString().padLeft(2, '0')}-'
                      '${generatedAt.day.toString().padLeft(2, '0')} '
                      '${generatedAt.hour.toString().padLeft(2, '0')}:'
                      '${generatedAt.minute.toString().padLeft(2, '0')}',
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
                sectionTitle('شروط الانضمام كوسيطة في بركة'),
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
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: signatureBox('اعتماد إدارة بركة'),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: signatureBox('توقيع الوسيطة'),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(
                  color: PdfColor.fromHex('#D4AF37'),
                ),
                pw.Text(
                  'هذه النسخة مرتبطة بالوسيطة رقم '
                  '${widget.agentId} ومحفوظة لأغراض السجل '
                  'الإداري في بركة.',
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

    return document.save();
  }

  Future<void> _downloadGeneratedContract(
    Map<String, dynamic> agentData,
  ) async {
    setState(() => _busy = true);

    try {
      final bytes = await _buildAgentContractPdf(agentData);

      final filename = 'barakah_agent_contract_${widget.agentId}.pdf';

      await downloadAdminAgentPdf(
        bytes,
        filename,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء عقد الوسيطة. يمكنك إرساله للطباعة والتوقيع ✅',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String> _token() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول بحساب الأدمن.');
    }

    final token = await user.getIdToken(true);

    if (token == null || token.isEmpty) {
      throw StateError('تعذر إنشاء جلسة رفع آمنة.');
    }

    return token;
  }

  String _bucket() {
    final bucket = Firebase.app().options.storageBucket;

    if (bucket == null || bucket.trim().isEmpty) {
      throw StateError(
        'Firebase Storage غير مهيأ في هذا المشروع.',
      );
    }

    return bucket.trim();
  }

  Future<Uint8List> _downloadSignedBytes(
    String storagePath,
  ) async {
    final token = await _token();
    final bucket = _bucket();

    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}',
      {'alt': 'media'},
    );

    final response = await http.get(
      uri,
      headers: {
        'authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'تعذر قراءة النسخة الموقعة '
        '(${response.statusCode}).',
      );
    }

    return response.bodyBytes;
  }

  Future<void> _uploadSignedContract() async {
    const typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );

    final file = await openFile(
      acceptedTypeGroups: const [typeGroup],
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('ملف العقد فارغ.');
    }

    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError(
        'حجم النسخة الموقعة أكبر من 10MB.',
      );
    }

    if (!file.name.toLowerCase().endsWith('.pdf')) {
      throw StateError('يجب اختيار ملف PDF فقط.');
    }

    setState(() => _busy = true);

    try {
      final token = await _token();
      final bucket = _bucket();

      final uri = Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/$bucket/o',
        {
          'uploadType': 'media',
          'name': _storagePath,
        },
      );

      final response = await http.post(
        uri,
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/pdf',
        },
        body: bytes,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String details = '';

        try {
          final parsed = jsonDecode(
            utf8.decode(response.bodyBytes),
          );

          if (parsed is Map &&
              parsed['error'] is Map &&
              parsed['error']['message'] != null) {
            details = parsed['error']['message'].toString();
          }
        } catch (_) {}

        throw StateError(
          details.isEmpty
              ? 'تعذر رفع النسخة الموقعة '
                  '(${response.statusCode}).'
              : 'تعذر رفع النسخة الموقعة: $details',
        );
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await _agentRef.update({
        'contractStoragePath': _storagePath,
        'contractFileName': file.name,
        'contractStatus': 'uploaded',
        'contractUploadedAt': FieldValue.serverTimestamp(),
        'contractUploadedBy': uid,
        'contractUpdatedAt': FieldValue.serverTimestamp(),
        'contractVersion': FieldValue.increment(1),
        'contractApprovedAt': FieldValue.delete(),
        'contractApprovedBy': FieldValue.delete(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم رفع النسخة الموقعة وهي بانتظار الاعتماد ✅',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _approveContract(
    Map<String, dynamic> data,
  ) async {
    final path = data['contractStoragePath']?.toString() ?? '';

    if (path.isEmpty) {
      throw StateError(
        'ارفعي النسخة الموقعة أولًا.',
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اعتماد النسخة الموقعة'),
        content: Text(
          'هل تؤكدين اعتماد عقد ${widget.agentName}؟\n\n'
          'سيتم تسجيل حساب الأدمن ووقت الاعتماد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await _agentRef.update({
        'contractStatus': 'approved',
        'contractApprovedAt': FieldValue.serverTimestamp(),
        'contractApprovedBy': uid,
        'contractUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم اعتماد النسخة الموقعة ✅',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _printSignedContract(
    Map<String, dynamic> data,
  ) async {
    final path = data['contractStoragePath']?.toString() ?? '';

    if (path.isEmpty) {
      throw StateError(
        'لا توجد نسخة موقعة مرفوعة.',
      );
    }

    setState(() => _busy = true);

    try {
      final bytes = await _downloadSignedBytes(path);

      await Printing.layoutPdf(
        name: 'عقد ${widget.agentName}',
        onLayout: (_) async => bytes,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadSignedContract(
    Map<String, dynamic> data,
  ) async {
    final path = data['contractStoragePath']?.toString() ?? '';

    if (path.isEmpty) {
      throw StateError(
        'لا توجد نسخة موقعة مرفوعة.',
      );
    }

    setState(() => _busy = true);

    try {
      final bytes = await _downloadSignedBytes(path);

      await downloadAdminAgentPdf(
        bytes,
        _fileName(data),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _guard(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'حدث خطأ أثناء معالجة العقد: $error',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF475569),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 155,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(
    String number,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF12284C),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _agentRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};

        final status = _status(data);
        final color = _statusColor(status);

        final hasSignedContract =
            (data['contractStoragePath']?.toString().trim() ?? '').isNotEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'عقد الوسيطة',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // نفس زر عقد الشركاء.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _guard(
                                () => _downloadGeneratedContract(
                                  data,
                                ),
                              ),
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                      ),
                      label: const Text(
                        'تحميل عقد PDF',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF12284C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _step(
                    '1',
                    'تحميل العقد وإرساله للوسيطة',
                    'بركة تنشئ نسخة PDF جاهزة ببيانات الوسيطة للطباعة والتوقيع.',
                  ),
                  const SizedBox(height: 8),
                  _step(
                    '2',
                    'استلام النسخة الموقعة',
                    'بعد توقيع الوسيطة، ارفعي ملف PDF الموقع هنا.',
                  ),
                  const SizedBox(height: 8),
                  _step(
                    '3',
                    'اعتماد النسخة النهائية',
                    'يتم تسجيل وقت الاعتماد وحساب الأدمن الذي اعتمد العقد.',
                  ),

                  const Divider(height: 32),

                  _infoRow(
                    Icons.person_outline_rounded,
                    'الوسيطة',
                    widget.agentName,
                  ),
                  _infoRow(
                    Icons.badge_outlined,
                    'المعرف',
                    widget.agentId,
                  ),
                  _infoRow(
                    Icons.picture_as_pdf_outlined,
                    'النسخة الموقعة',
                    hasSignedContract ? _fileName(data) : 'غير مرفوعة',
                  ),
                  _infoRow(
                    Icons.history_rounded,
                    'رقم النسخة',
                    '${data['contractVersion'] ?? 0}',
                  ),
                  _infoRow(
                    Icons.cloud_upload_outlined,
                    'وقت رفع الموقعة',
                    _formatTimestamp(
                      data['contractUploadedAt'],
                    ),
                  ),
                  _infoRow(
                    Icons.verified_user_outlined,
                    'وقت الاعتماد',
                    _formatTimestamp(
                      data['contractApprovedAt'],
                    ),
                  ),

                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),

                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _guard(
                                  _uploadSignedContract,
                                ),
                        icon: const Icon(
                          Icons.upload_file_rounded,
                        ),
                        label: Text(
                          hasSignedContract
                              ? 'استبدال النسخة الموقعة'
                              : 'رفع النسخة الموقعة',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !hasSignedContract
                            ? null
                            : () => _guard(
                                  () => _printSignedContract(
                                    data,
                                  ),
                                ),
                        icon: const Icon(
                          Icons.print_rounded,
                        ),
                        label: const Text(
                          'فتح / طباعة الموقعة',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !hasSignedContract
                            ? null
                            : () => _guard(
                                  () => _downloadSignedContract(
                                    data,
                                  ),
                                ),
                        icon: const Icon(
                          Icons.download_rounded,
                        ),
                        label: const Text(
                          'تنزيل النسخة الموقعة',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _busy || !hasSignedContract || status == 'approved'
                                ? null
                                : () => _guard(
                                      () => _approveContract(
                                        data,
                                      ),
                                    ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF138A5B),
                        ),
                        icon: const Icon(
                          Icons.verified_rounded,
                        ),
                        label: const Text(
                          'اعتماد النسخة الموقعة',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF3D98A),
                      ),
                    ),
                    child: const Text(
                      'عند استبدال النسخة الموقعة تُلغى حالة '
                      'الاعتماد السابقة تلقائيًا حتى يراجعها '
                      'الأدمن ويعتمد النسخة الجديدة.',
                      style: TextStyle(
                        color: Color(0xFF6B5300),
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
