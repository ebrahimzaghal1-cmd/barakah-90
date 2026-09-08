import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class AuctionActivityScreen extends StatelessWidget {
  const AuctionActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('سجّل الدخول لمتابعة عمليات المزاد.')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('عملياتي في المزاد'),
            centerTitle: true,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'مشترياتي'),
                Tab(text: 'مبيعاتي'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _AuctionSalesList(field: 'buyerId', userId: user.uid),
              _AuctionSalesList(field: 'sellerId', userId: user.uid),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuctionSalesList extends StatelessWidget {
  const _AuctionSalesList({required this.field, required this.userId});

  final String field;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('auction_sales')
          .where(field, isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل عمليات المزاد.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            final bTime = (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            return bTime.compareTo(aTime);
          });
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد عمليات مزاد حتى الآن.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _AuctionSaleCard(
              data: docs[index].data(), isBuyer: field == 'buyerId'),
        );
      },
    );
  }
}

class _AuctionSaleCard extends StatelessWidget {
  const _AuctionSaleCard({required this.data, required this.isBuyer});

  final Map<String, dynamic> data;
  final bool isBuyer;

  ({String label, Color color, String guidance}) _statusInfo(String status) {
    switch (status) {
      case 'commission_paid':
        return (
          label: 'تم استلام العمولة',
          color: const Color(0xFF167A45),
          guidance: isBuyer
              ? 'تم تأكيد العمولة. ستتابع بركة مع البائع لإتمام التسليم.'
              : 'تم تأكيد العمولة. نسّق التسليم مع إدارة بركة.',
        );
      case 'completed':
        return (
          label: 'تم البيع',
          color: const Color(0xFF167A45),
          guidance: 'اكتملت عملية البيع بنجاح.',
        );
      case 'cancelled':
        return (
          label: 'ملغاة',
          color: Colors.red.shade700,
          guidance: 'أُلغي الحجز وأعيدت السلعة للبيع.',
        );
      default:
        return (
          label: 'بانتظار العمولة',
          color: const Color(0xFF9A6200),
          guidance: isBuyer
              ? 'تواصل مع بركة لإتمام دفع العمولة وتأكيد الحجز.'
              : 'السلعة محجوزة. لا تسلّمها قبل تأكيد استلام العمولة من بركة.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'pending_commission';
    final info = _statusInfo(status);
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['itemName']?.toString() ?? 'سلعة مزاد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: info.color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    info.label,
                    style: TextStyle(
                        color: info.color, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('السعر: ${data['salePrice'] ?? 0} ₪'),
            Text('عمولة بركة: ${data['commissionAmount'] ?? 0} ₪'),
            if (createdAt != null)
              Text(
                'تاريخ الحجز: ${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
              ),
            const SizedBox(height: 10),
            Text(info.guidance,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (status == 'pending_commission' && isBuyer) ...[
              const SizedBox(height: 12),
              const _AuctionSupportActions(),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuctionSupportActions extends StatelessWidget {
  const _AuctionSupportActions();

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح وسيلة التواصل.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('support_contact')
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final phone = data['phone']?.toString().trim() ?? '';
        final whatsapp =
            (data['whatsapp']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
        if (phone.isEmpty && whatsapp.isEmpty) {
          return const Text('تواصل مع إدارة بركة لتأكيد العمولة.');
        }
        return Row(
          children: [
            if (whatsapp.isNotEmpty)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _open(
                    context,
                    Uri.parse(
                      'https://wa.me/$whatsapp?text=${Uri.encodeComponent('مرحباً بركة، أريد إتمام عمولة عملية المزاد.')}',
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('واتساب'),
                ),
              ),
            if (whatsapp.isNotEmpty && phone.isNotEmpty)
              const SizedBox(width: 8),
            if (phone.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(context, Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.phone_rounded),
                  label: const Text('اتصال'),
                ),
              ),
          ],
        );
      },
    );
  }
}
