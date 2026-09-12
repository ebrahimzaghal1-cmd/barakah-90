import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/order_service.dart';
import 'admin_live_order.dart';
import 'admin_manage_orders.dart';
import 'admin_manage_products.dart';
import 'admin_manage_users.dart';
import 'admin_business_accounting_screen.dart';

const _bg = Color(0xFF061523);
const _panel = Color(0xFF102437);
const _border = Color(0xFF28445B);
const _gold = Color(0xFFEAC16E);
const _muted = Color(0xFFB6C8DA);
const _green = Color(0xFF9AD9B8);

class AdminLiveDashboard extends StatefulWidget {
  const AdminLiveDashboard(
      {super.key, required this.onTools, this.ordersStream});
  final VoidCallback onTools;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? ordersStream;
  @override
  State<AdminLiveDashboard> createState() => _AdminLiveDashboardState();
}

class _AdminLiveDashboardState extends State<AdminLiveDashboard> {
  late final _orders = widget.ordersStream ?? OrderService().allOrders();
  final _search = TextEditingController();
  final _productLookups =
      <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};
  Timer? _clock;
  String _filter = 'active';
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  String _money(num amount) => '${amount.toStringAsFixed(2)} ₪';
  Widget _text(String value,
          {double size = 14,
          Color color = Colors.white,
          FontWeight weight = FontWeight.w600}) =>
      Text(value,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight));
  Widget _box(Widget child, {EdgeInsets padding = const EdgeInsets.all(18)}) =>
      Container(
          padding: padding,
          decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border)),
          child: child);
  Widget _badge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10)),
      child: _text(text, color: color, size: 12));
  Widget _button(String label, VoidCallback action,
          {IconData icon = Icons.arrow_back_rounded}) =>
      OutlinedButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11))));

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: _bg,
            body: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
              final desktop = bounds.maxWidth >= 1050;
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) SizedBox(width: 110, child: _navigation()),
                    Expanded(
                        child: Column(children: [
                      _header(desktop),
                      Expanded(
                          child: StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                        stream: _orders,
                        builder: (context, snapshot) {
                          if (snapshot.hasError)
                            return Center(
                                child: _text(
                                    'تعذر تحميل البيانات. تحقق من الاتصال وصلاحية الحساب.'));
                          if (!snapshot.hasData)
                            return const Center(
                                child: CircularProgressIndicator(color: _gold));
                          final orders = snapshot.data!.docs
                              .map((d) => AdminLiveOrder(d.id, d.data()))
                              .toList()
                            ..sort((a, b) => (b
                                        .createdAt?.millisecondsSinceEpoch ??
                                    0)
                                .compareTo(
                                    a.createdAt?.millisecondsSinceEpoch ?? 0));
                          final filtered = orders
                              .where((o) =>
                                  o.matches(_search.text) &&
                                  switch (_filter) {
                                    'active' => o.active,
                                    'new' => o.status == 'new',
                                    'preparing' => ['accepted', 'preparing']
                                        .contains(o.status),
                                    'ready' => [
                                        'ready',
                                        'awaiting_driver',
                                        'driver_assigned',
                                        'picked_up'
                                      ].contains(o.status),
                                    'complete' => o.complete,
                                    _ => true,
                                  })
                              .toList();
                          final now = DateTime.now();
                          final today = orders
                              .where((o) =>
                                  o.createdAt != null &&
                                  DateUtils.isSameDay(o.createdAt, now) &&
                                  !o.cancelled)
                              .toList();
                          final cache = snapshot.data!.metadata.isFromCache;
                          if (desktop)
                            return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 18),
                                child: Column(children: [
                                  Expanded(
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                        Expanded(
                                            child: _ordersPanel(filtered,
                                                cache: cache)),
                                        const SizedBox(width: 18),
                                        SizedBox(
                                            width: bounds.maxWidth >= 1400
                                                ? 340
                                                : 290,
                                            child: _box(SingleChildScrollView(
                                                child: _accounting(today)))),
                                      ])),
                                  const SizedBox(height: 16),
                                  _summary(orders),
                                ]));
                          return Column(children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: _box(
                                    Row(children: [
                                      Expanded(
                                          child: _metric('طلبات اليوم',
                                              '${today.length}', _gold)),
                                      Expanded(
                                          child: _metric(
                                              'مبيعات مسلّمة اليوم',
                                              _money(today
                                                  .where((o) => o.complete)
                                                  .fold<double>(0,
                                                      (s, o) => s + o.total)),
                                              _green))
                                    ]),
                                    padding: const EdgeInsets.all(12))),
                            Expanded(
                                child: ListView(
                                    padding: const EdgeInsets.all(12),
                                    children: [
                                  _ordersPanel(filtered,
                                      cache: cache, scrolling: false),
                                  const SizedBox(height: 14),
                                  _box(_accounting(today)),
                                  const SizedBox(height: 14),
                                  _summary(orders),
                                ])),
                          ]);
                        },
                      )),
                    ])),
                  ]);
            }))),
      );

  Widget _header(bool desktop) => Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        if (!desktop)
          IconButton(
              onPressed: widget.onTools,
              icon: const Icon(Icons.menu, color: _gold),
              tooltip: 'أدوات الإدارة'),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _text('لوحة التشغيل', size: 25, weight: FontWeight.w800),
          _text('الطلبات والمحاسبة في مكان واحد', color: _muted, size: 12),
        ])),
        if (desktop) SizedBox(width: 340, child: _searchField()),
        const SizedBox(width: 12),
        IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'العودة للتطبيق',
            icon: const Icon(Icons.exit_to_app, color: _gold)),
      ]));
  Widget _searchField() => TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          hintText: 'ابحث عن طلب، عميل، أو منتج…',
          hintStyle: const TextStyle(color: _muted, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: _muted),
          filled: true,
          fillColor: _panel,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: const BorderSide(color: _gold))));
  Widget _navigation() => Container(
      decoration:
          const BoxDecoration(border: Border(left: BorderSide(color: _border))),
      child: Column(children: [
        const SizedBox(height: 22),
        _text('بركة', size: 32, color: _gold, weight: FontWeight.w900),
        const SizedBox(height: 26),
        Expanded(
            child: SingleChildScrollView(
                child: Column(children: [
          _nav(
              'الرئيسية',
              Icons.home_rounded,
              () => setState(() {
                    _filter = 'active';
                    _search.clear();
                  }),
              selected: true),
          _nav('الطلبات', Icons.receipt_long,
              () => setState(() => _filter = 'all')),
          _nav('المنتجات', Icons.inventory_2_outlined,
              () => _open(const AdminManageProducts())),
          _nav('العملاء', Icons.people_outline,
              () => _open(const AdminManageUsers())),
          _nav('المحاسبة', Icons.account_balance_wallet_outlined,
              () => _open(const AdminBusinessAccountingScreen())),
          _nav('أدوات الإدارة', Icons.grid_view_rounded, widget.onTools),
        ]))),
        _nav('عودة للتطبيق', Icons.logout, () => Navigator.maybePop(context)),
        const SizedBox(height: 12),
      ]));
  Widget _nav(String title, IconData icon, VoidCallback action,
          {bool selected = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
              color: selected ? _panel : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                  onTap: action,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      child: SizedBox(
                          width: double.infinity,
                          child: Column(children: [
                            Icon(icon,
                                color: selected ? _gold : Colors.white,
                                size: 25),
                            const SizedBox(height: 7),
                            _text(title, size: 11)
                          ]))))));
  Widget _ordersPanel(List<AdminLiveOrder> orders,
      {required bool cache, bool scrolling = true}) {
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _text('الطلبات الحالية', size: 21)),
        _badge(cache ? 'نسخة محفوظة • جارٍ المزامنة' : 'تحديث مباشر',
            cache ? _gold : _green)
      ]),
      const SizedBox(height: 12),
      if (MediaQuery.sizeOf(context).width < 1050) ...[
        _searchField(),
        const SizedBox(height: 12)
      ],
      Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const <String, String>{
            'active': 'الجارية',
            'new': 'جديد',
            'preparing': 'قيد التجهيز',
            'ready': 'التسليم',
            'complete': 'المسلّمة',
            'all': 'الكل'
          }
              .entries
              .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                    selectedColor: _gold,
                    backgroundColor: _bg,
                    side: const BorderSide(color: _border),
                    labelStyle:
                        TextStyle(color: _filter == e.key ? _bg : _muted),
                    showCheckmark: false,
                  ))
              .toList()),
      const SizedBox(height: 14),
      if (!scrolling)
        _cards(orders)
      else
        Expanded(child: SingleChildScrollView(child: _cards(orders))),
    ]);
    return _box(content);
  }

  Widget _cards(List<AdminLiveOrder> orders) =>
      LayoutBuilder(builder: (context, bounds) {
        if (orders.isEmpty)
          return Padding(
              padding: const EdgeInsets.all(30),
              child:
                  _text('لا توجد طلبات مطابقة للعرض المحدد.', color: _muted));
        final two = bounds.maxWidth >= 610;
        return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: orders
                .map((o) => SizedBox(
                    width: two ? (bounds.maxWidth - 14) / 2 : bounds.maxWidth,
                    child: _orderCard(o)))
                .toList());
      });
  Widget _orderCard(AdminLiveOrder order) {
    final items = order.items;
    final line = items.isEmpty ? <String, dynamic>{} : items.first;
    final age = order.createdAt == null ? '' : _age(order.createdAt!);
    return _box(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(order.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Flexible(child: _text('#${order.number}', color: _gold, size: 13))
          ]),
          const SizedBox(height: 6),
          Text('${order.data['businessTitle'] ?? ''} • $age',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _bg.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _productImage(line),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${line['title'] ?? 'تفاصيل الطلب'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      _text('${items.length} أصناف • ${_money(order.total)}',
                          color: _muted, size: 12),
                    ]))
              ])),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _badge(order.statusLabel, order.complete ? _green : _gold),
            _badge(
                order.paymentLabel,
                order.paid == order.total && order.paid != null
                    ? _green
                    : _muted),
          ]),
          const SizedBox(height: 15),
          _button('عرض ومتابعة الطلب',
              () => _open(AdminManageOrders(orderId: order.id))),
        ]),
        padding: const EdgeInsets.all(15));
  }

  Widget _productImage(Map<String, dynamic> item) {
    final image = '${item['image'] ?? ''}';
    final productId = '${item['productId'] ?? ''}';
    if (image.isEmpty && productId.isNotEmpty && item['_resolved'] != true) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _productLookups.putIfAbsent(
            productId,
            () => FirebaseFirestore.instance
                .collection('items')
                .doc(productId)
                .get()),
        builder: (context, snapshot) => _productImage({
          ...item,
          '_resolved': true,
          'image': snapshot.data?.data()?['image'] ?? '',
        }),
      );
    }
    final fallback = Container(
        color: _border,
        child: const Icon(Icons.shopping_bag_outlined, color: _gold));
    return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
            width: 62,
            height: 62,
            child: image.startsWith('https://') || image.startsWith('http://')
                ? Image.network(image,
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
                : image.startsWith('assets/')
                    ? Image.asset(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback)
                    : fallback));
  }

  String _age(DateTime date) {
    final minutes = DateTime.now().difference(date).inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes دقيقة';
    if (minutes < 1440) return 'منذ ${minutes ~/ 60} ساعة';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _metric(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _text(value, size: 22, color: color, weight: FontWeight.w800),
        const SizedBox(height: 6),
        _text(label, size: 12, color: _muted),
      ]);
  Widget _accounting(List<AdminLiveOrder> today) {
    final delivered = today.where((o) => o.complete).toList();
    final sales = delivered.fold<double>(0, (s, o) => s + o.total);
    final commission = delivered.fold<double>(0, (s, o) => s + o.commission);
    final known = today.where((o) => o.paid != null).toList();
    final unknown = today.length - known.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet_outlined, color: _gold),
        const SizedBox(width: 9),
        Expanded(child: _text('المحاسبة اليوم', size: 21))
      ]),
      const SizedBox(height: 6),
      _text('طلبات اليوم • البيانات الفعلية', color: _muted, size: 12),
      const SizedBox(height: 22),
      _box(_metric('قيمة الطلبات المسلّمة', _money(sales), _green)),
      const SizedBox(height: 12),
      _box(_metric('عمولات الطلبات المسلّمة', _money(commission), _gold)),
      const SizedBox(height: 12),
      _box(_metric(
          'تحصيل مسجّل لطلبات اليوم',
          known.isEmpty
              ? 'غير مسجّل'
              : _money(known.fold<double>(0, (s, o) => s + o.paid!)),
          _green)),
      if (unknown > 0)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _text(
                '$unknown طلب دون تأكيد تحصيل. التسليم لا يعني تأكيد الدفع.',
                size: 11,
                color: _muted)),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: _border)),
      _text('آخر الطلبات المسلّمة', size: 17),
      const SizedBox(height: 12),
      if (delivered.isEmpty)
        _text('لا توجد طلبات مسلّمة من طلبات اليوم بعد.',
            color: _muted, size: 12),
      ...delivered.take(4).map((o) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
              onTap: () => _open(AdminManageOrders(orderId: o.id)),
              child: _box(
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text('#${o.number} • ${_money(o.total)}', size: 13),
                        const SizedBox(height: 4),
                        Text(o.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                      ]),
                  padding: const EdgeInsets.all(12))))),
      const SizedBox(height: 16),
      _button('المحاسبة الكاملة',
          () => _open(const AdminBusinessAccountingScreen()),
          icon: Icons.account_balance_wallet_outlined),
    ]);
  }

  Widget _summary(List<AdminLiveOrder> orders) => _box(Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 28,
          runSpacing: 14,
          children: [
            _metric('طلبات جديدة',
                '${orders.where((o) => o.status == 'new').length}', _green),
            _metric(
                'قيد التجهيز',
                '${orders.where((o) => [
                      'accepted',
                      'preparing'
                    ].contains(o.status)).length}',
                _gold),
            _metric(
                'جاهزة للتسليم',
                '${orders.where((o) => [
                      'ready',
                      'awaiting_driver'
                    ].contains(o.status)).length}',
                const Color(0xFF8CBFED)),
            _metric(
                'مع السائق',
                '${orders.where((o) => [
                      'picked_up',
                      'driver_assigned'
                    ].contains(o.status)).length}',
                _muted),
          ]));
}
