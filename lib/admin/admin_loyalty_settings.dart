import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLoyaltySettings extends StatefulWidget {
  const AdminLoyaltySettings({super.key});
  @override
  State<AdminLoyaltySettings> createState() => _AdminLoyaltySettingsState();
}

class _AdminLoyaltySettingsState extends State<AdminLoyaltySettings> {
  final pointsPerShekel = TextEditingController(text: '2');
  final redemptionPoints = TextEditingController(text: '1000');
  final redemptionValue = TextEditingController(text: '10');
  bool saving = false;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('app_settings')
        .doc('loyalty')
        .get()
        .then((doc) {
      if (!mounted || !doc.exists) return;
      pointsPerShekel.text = (doc.data()?['pointsPerShekel'] ?? 2).toString();
      redemptionPoints.text =
          (doc.data()?['redemptionPoints'] ?? 1000).toString();
      redemptionValue.text = (doc.data()?['redemptionValue'] ?? 10).toString();
      setState(() {});
    });
  }

  @override
  void dispose() {
    pointsPerShekel.dispose();
    redemptionPoints.dispose();
    redemptionValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('إعدادات نقاط بركة'), centerTitle: true),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          const Icon(Icons.card_giftcard_rounded, size: 82),
          const Text('مكافآت بركة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 22),
          const Text(
            'كسب نقاط بركة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pointsPerShekel,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد النقاط لكل 1 شيكل مشتريات',
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'استخدام النقاط للدفع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: redemptionPoints,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد النقاط المطلوب للاستبدال',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: redemptionValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'قيمة هذه النقاط بالشيكل',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'النظام المعتمد حاليًا: 1000 نقطة = 10 شيكل',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);

                    final earnedPerShekel =
                        int.tryParse(pointsPerShekel.text) ?? 2;
                    final redeemPoints =
                        int.tryParse(redemptionPoints.text) ?? 1000;
                    final redeemValue =
                        num.tryParse(redemptionValue.text) ?? 10;

                    if (earnedPerShekel <= 0 ||
                        redeemPoints <= 0 ||
                        redeemValue <= 0) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('تحقق من قيم إعدادات النقاط.'),
                        ),
                      );
                      return;
                    }

                    setState(() => saving = true);

                    await FirebaseFirestore.instance
                        .collection('app_settings')
                        .doc('loyalty')
                        .set({
                      'pointsPerShekel': earnedPerShekel,
                      'redemptionPoints': redeemPoints,
                      'redemptionValue': redeemValue,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (!mounted) return;

                    setState(() => saving = false);

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ إعدادات نقاط بركة.'),
                      ),
                    );
                  },
            child: const Text('حفظ الإعدادات'),
          ),
        ]),
      );
}
