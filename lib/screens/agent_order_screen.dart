import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';

class AgentOrderScreen extends StatefulWidget {
  const AgentOrderScreen({
    super.key,
    required this.agentId,
    required this.agent,
  });

  final String agentId;
  final Map<String, dynamic> agent;

  @override
  State<AgentOrderScreen> createState() => _AgentOrderScreenState();
}

class _AgentOrderScreenState extends State<AgentOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _payment = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = profile.data() ?? const <String, dynamic>{};
    _phone.text = data['phone']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
  }

  @override
  void dispose() {
    _details.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_payment == 'card') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الدفع ببطاقة Visa سيُفعّل بعد ربط بوابة الدفع الآمنة. اختر الدفع عند الاستلام الآن.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولًا لإرسال الطلب.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final token = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(
          'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/agent-orders',
        ),
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'agentId': widget.agentId,
          'details': _details.text.trim(),
          'customerPhone': _phone.text.trim(),
          'deliveryAddress': _address.text.trim(),
          'paymentMethod': _payment,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(utf8.decode(response.bodyBytes));
        throw StateError(body is Map && body['message'] != null
            ? body['message'].toString()
            : 'تعذر إرسال الطلب.');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('تم إرسال الطلب'),
          content: Text(
            'وصل طلبك إلى ${widget.agent['title'] ?? 'الوسيطة'} وسيتم التواصل معك.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is StateError
              ? error.message.toString()
              : 'تعذر إرسال الطلب.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('طلب من ${widget.agent['title'] ?? 'الوسيطة'}'),
          centerTitle: true,
        ),
        backgroundColor: Colors.transparent,
        body: BarakahBrandBackdrop(
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.coolYellow.withOpacity(.55),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.support_agent_rounded,
                            size: 48, color: AppTheme.deepYellow),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _details,
                          minLines: 4,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText: 'ماذا تريد أن تطلب؟',
                            hintText: 'اكتب تفاصيل المنتجات والكميات المطلوبة',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 3
                                  ? 'اكتب تفاصيل الطلب'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 6
                                  ? 'أدخل رقم هاتف صحيحًا'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                            labelText: 'عنوان التسليم',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 3
                                  ? 'أدخل عنوان التسليم'
                                  : null,
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            'طريقة الدفع',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'cash',
                          groupValue: _payment,
                          onChanged: (value) =>
                              setState(() => _payment = value!),
                          title: const Text('الدفع عند الاستلام'),
                          secondary: const Icon(Icons.payments_outlined),
                        ),
                        RadioListTile<String>(
                          value: 'card',
                          groupValue: _payment,
                          onChanged: (value) =>
                              setState(() => _payment = value!),
                          title: const Text('Visa / بطاقة بنكية'),
                          subtitle: const Text('قريبًا بعد ربط بوابة الدفع'),
                          secondary: const Icon(Icons.credit_card_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text(
                      'إرسال الطلب إلى الوسيطة',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
