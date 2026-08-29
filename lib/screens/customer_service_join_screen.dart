import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/customer_service_service.dart';
import '../theme/app_theme.dart';
import 'authentication_screen.dart';
import 'recruitment_chat_screen.dart';

class CustomerServiceJoinScreen extends StatefulWidget {
  const CustomerServiceJoinScreen({super.key});

  @override
  State<CustomerServiceJoinScreen> createState() =>
      _CustomerServiceJoinScreenState();
}

class _CustomerServiceJoinScreenState extends State<CustomerServiceJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _experience = TextEditingController();
  final _motivation = TextEditingController();
  String _availability = 'دوام كامل';
  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _name.text = user?.displayName ?? '';
    _email.text = user?.email ?? '';
    _phone.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _experience.dispose();
    _motivation.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthenticationScreen()),
      );
      if (!mounted || FirebaseAuth.instance.currentUser == null) return;
    }
    setState(() => _saving = true);
    try {
      await CustomerServiceService().apply(
        fullName: _name.text,
        phone: _phone.text,
        email: _email.text,
        city: _city.text,
        experience: _experience.text,
        availability: _availability,
        motivation: _motivation.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        title: const Text('الانضمام لخدمة العملاء',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: CustomerServiceService().recruitmentSettings(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final hiringOpen = data['hiringOpen'] == true;
          final message = data['message']?.toString().trim() ?? '';
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            if (!hiringOpen) return _closed(message);
            return _submitted ? _success() : _form(message);
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('customer_service_applications')
                .doc(user.uid)
                .snapshots(),
            builder: (context, applicationSnapshot) {
              final application = applicationSnapshot.data?.data();
              if (_submitted || application != null) {
                return _applicationStatus(application);
              }
              if (!hiringOpen) return _closed(message);
              return _form(message);
            },
          );
        },
      ),
    );
  }

  Widget _applicationStatus(Map<String, dynamic>? application) {
    final status = application?['status']?.toString() ?? 'pending';
    final title = switch (status) {
      'approved' => 'تم قبول طلبك وإصدار الوثيقة ✅',
      'rejected' => 'تمت مراجعة الطلب',
      _ => 'طلبك قيد المراجعة',
    };
    final subtitle = switch (status) {
      'approved' =>
        'ادخل من صفحتي إلى بوابة موظف خدمة العملاء لقراءة وثيقة التوظيف وتوقيعها.',
      'rejected' => 'يمكنك التواصل مع فريق التوظيف للاستفسار عن النتيجة.',
      _ => 'يمكنك التواصل مع فريق التوظيف من داخل بركة ومتابعة طلبك.',
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _hero(title: title, subtitle: subtitle),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecruitmentChatScreen(
                  applicantId: user.uid,
                  applicantName: application?['fullName']?.toString() ??
                      (_name.text.trim().isEmpty ? 'متقدم' : _name.text.trim()),
                ),
              ),
            );
          },
          icon: const Icon(Icons.forum_rounded),
          label: const Text('محادثة فريق التوظيف داخل بركة'),
        ),
      ],
    );
  }

  Widget _hero({required String title, required String subtitle}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: AppTheme.coolYellow,
              child: Icon(Icons.headset_mic_rounded,
                  size: 42, color: AppTheme.navy),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.6)),
          ],
        ),
      );

  Widget _closed(String message) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _hero(
            title: 'فريق بركة مكتمل حالياً',
            subtitle: message.isEmpty
                ? 'نشكر اهتمامك. سنفتح باب الانضمام هنا فور توفر شواغر جديدة.'
                : message,
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      color: AppTheme.deepYellow),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا يمكن إرسال طلبات جديدة إلا عندما يفعّل الأدمن خيار التوظيف.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _success() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _hero(
                title: 'وصل طلبك إلى بركة ✅',
                subtitle:
                    'سيراجع الأدمن بياناتك، ويمكنكما التواصل هنا حتى إصدار وثيقة التوظيف.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecruitmentChatScreen(
                          applicantId: user.uid,
                          applicantName: _name.text.trim().isEmpty
                              ? 'متقدم'
                              : _name.text.trim(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('محادثة فريق التوظيف داخل بركة'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _form(String message) => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            _hero(
              title: 'كن صوت بركة القريب من العملاء',
              subtitle: message.isEmpty
                  ? 'باب الانضمام مفتوح الآن. نبحث عن شخص لبق، صبور وسريع في المساعدة.'
                  : message,
            ),
            const SizedBox(height: 20),
            _field(_name, 'الاسم الكامل', Icons.person_outline_rounded),
            _field(_phone, 'رقم الهاتف', Icons.phone_outlined,
                keyboard: TextInputType.phone),
            _field(_email, 'البريد الإلكتروني', Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            _field(_city, 'المدينة / المنطقة', Icons.location_on_outlined),
            _field(_experience, 'الخبرة في خدمة العملاء', Icons.badge_outlined,
                maxLines: 3),
            DropdownButtonFormField<String>(
              value: _availability,
              decoration: const InputDecoration(
                labelText: 'نوع الدوام المناسب',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'دوام كامل', child: Text('دوام كامل')),
                DropdownMenuItem(value: 'دوام جزئي', child: Text('دوام جزئي')),
                DropdownMenuItem(value: 'مسائي', child: Text('مسائي')),
              ],
              onChanged: (value) =>
                  setState(() => _availability = value ?? 'دوام كامل'),
            ),
            const SizedBox(height: 13),
            _field(_motivation, 'لماذا ترغب بالانضمام إلى بركة؟',
                Icons.auto_awesome_outlined,
                maxLines: 4),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coolYellow,
                foregroundColor: AppTheme.navy,
                minimumSize: const Size.fromHeight(56),
              ),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20, child: CircularProgressIndicator())
                  : const Icon(Icons.send_rounded),
              label: const Text('إرسال طلب الانضمام',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: TextFormField(
          controller: controller,
          validator: _required,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}
