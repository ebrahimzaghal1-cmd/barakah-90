import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminBusinessAccountingScreen extends StatefulWidget {
  const AdminBusinessAccountingScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<AdminBusinessAccountingScreen> createState() =>
      _AdminBusinessAccountingScreenState();
}

class _AdminBusinessAccountingScreenState
    extends State<AdminBusinessAccountingScreen> {
  String selectedPeriod = 'اليوم';

  static const double defaultCommissionRate = 10.0;

  DateTime _periodStart() {
    final now = DateTime.now();

    switch (selectedPeriod) {
      case 'الأسبوع':
        final startOfToday = DateTime(now.year, now.month, now.day);
        return startOfToday.subtract(
          Duration(days: now.weekday - 1),
        );

      case 'الشهر':
        return DateTime(now.year, now.month, 1);

      case 'اليوم':
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  bool _isInsideSelectedPeriod(Timestamp? timestamp) {
    if (timestamp == null) return false;

    final date = timestamp.toDate().toLocal();
    final start = _periodStart();

    return !date.isBefore(start);
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _itemSubtotal(Map<String, dynamic> item) {
    final explicitSubtotal = _toDouble(
      item['subtotal'] ?? item['lineTotal'],
    );

    if (explicitSubtotal > 0) {
      return explicitSubtotal;
    }

    final price = _toDouble(item['price']);
    final quantity = _toInt(item['quantity']);

    return price * (quantity <= 0 ? 1 : quantity);
  }

  Map<String, _BusinessInfo> _buildBusinessIndex(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, _BusinessInfo>{};

    for (final doc in docs) {
      final data = doc.data();

      if (data['kind']?.toString() == 'product') {
        continue;
      }

      final title = data['title']?.toString().trim() ?? '';

      final commissionRate = _toDouble(
        data['commissionRate'],
      );
      final hasValidCommission = data.containsKey('commissionRate') &&
          commissionRate >= 0 &&
          commissionRate <= 100;

      final business = _BusinessInfo(
        id: doc.id,
        title: title.isEmpty ? 'محل بدون اسم' : title,
        commissionRate:
            hasValidCommission ? commissionRate : defaultCommissionRate,
      );

      result[doc.id] = business;

      if (title.isNotEmpty) {
        result['title:$title'] = business;
      }
    }

    return result;
  }

  List<_BusinessAccountingRow> _calculateRows({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    required Map<String, _BusinessInfo> businesses,
  }) {
    final rows = <String, _BusinessAccountingRow>{};

    for (final order in orders) {
      final orderData = order.data();

      final status = orderData['status']?.toString().trim().toLowerCase() ?? '';

      // الطلبات النهائية التي تدخل المحاسبة.
      const completedStatuses = {
        'delivered',
        'completed',
        'finished',
      };

      if (!completedStatuses.contains(status)) {
        continue;
      }

      final rawAccountingDate = orderData['deliveredAt'] ??
          orderData['completedAt'] ??
          orderData['updatedAt'] ??
          orderData['createdAt'];

      final accountingDate =
          rawAccountingDate is Timestamp ? rawAccountingDate : null;

      if (!_isInsideSelectedPeriod(accountingDate)) {
        continue;
      }

      final items = orderData['items'] as List? ?? const [];

      final businessesInThisOrder = <String>{};

      for (final rawItem in items) {
        if (rawItem is! Map) {
          continue;
        }

        final item = Map<String, dynamic>.from(rawItem);

        final itemBusinessId = item['businessId']?.toString().trim() ?? '';

        final orderBusinessId =
            orderData['businessId']?.toString().trim() ?? '';

        final businessId =
            itemBusinessId.isNotEmpty ? itemBusinessId : orderBusinessId;

        final itemBusinessTitle =
            item['businessTitle']?.toString().trim() ?? '';

        final orderBusinessTitle =
            orderData['businessTitle']?.toString().trim() ?? '';

        final businessTitle = itemBusinessTitle.isNotEmpty
            ? itemBusinessTitle
            : orderBusinessTitle;

        _BusinessInfo? business;

        if (businessId.isNotEmpty) {
          business = businesses[businessId];
        }

        business ??= businessTitle.isNotEmpty
            ? businesses['title:$businessTitle']
            : null;

        final rowKey = business?.id ??
            (businessId.isNotEmpty
                ? businessId
                : businessTitle.isNotEmpty
                    ? 'title:$businessTitle'
                    : 'unknown');

        final displayTitle = business?.title ??
            (businessTitle.isNotEmpty ? businessTitle : 'محل غير محدد');

        // عمولة بركة المعتمدة ثابتة 10% لجميع الطلبات.
        const commissionRate = 10.0;

        final subtotal = _itemSubtotal(item);

        if (subtotal <= 0) {
          continue;
        }

        final row = rows.putIfAbsent(
          rowKey,
          () => _BusinessAccountingRow(
            businessId: businessId,
            title: displayTitle,
            commissionRate: commissionRate,
          ),
        );

        row.sales += subtotal;
        row.commission += subtotal * commissionRate / 100;
        row.itemCount +=
            _toInt(item['quantity']) <= 0 ? 1 : _toInt(item['quantity']);

        businessesInThisOrder.add(rowKey);
      }

      for (final rowKey in businessesInThisOrder) {
        final row = rows[rowKey];

        if (row != null) {
          row.orderIds.add(order.id);
        }
      }

      // دعم الطلبات القديمة التي لا تحتوي items مكتملة.
      final alreadyCounted = rows.values.any(
        (row) => row.orderIds.contains(order.id),
      );

      if (!alreadyCounted) {
        final businessId = orderData['businessId']?.toString().trim() ?? '';

        final businessTitle =
            orderData['businessTitle']?.toString().trim() ?? '';

        final fallbackAmount = _toDouble(
          orderData['subtotal'] ?? orderData['total'],
        );

        if (fallbackAmount > 0) {
          final business = businessId.isNotEmpty
              ? businesses[businessId]
              : businessTitle.isNotEmpty
                  ? businesses['title:$businessTitle']
                  : null;

          final rowKey = business?.id ??
              (businessId.isNotEmpty
                  ? businessId
                  : businessTitle.isNotEmpty
                      ? 'title:$businessTitle'
                      : 'unknown');

          final row = rows.putIfAbsent(
            rowKey,
            () => _BusinessAccountingRow(
              businessId: businessId,
              title: business?.title ??
                  (businessTitle.isNotEmpty ? businessTitle : 'محل غير محدد'),
              commissionRate: 10.0,
            ),
          );

          row.sales += fallbackAmount;
          row.commission += fallbackAmount * 0.10;
          row.itemCount += 1;
          row.orderIds.add(order.id);
        }
      }
    }

    final result = rows.values.toList();

    result.sort(
      (a, b) => b.sales.compareTo(a.sales),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final storesContent = Column(
      children: [
        _buildPeriodSelector(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, businessSnapshot) {
              if (businessSnapshot.hasError) {
                return const Center(
                  child: Text('تعذر تحميل بيانات المحلات.'),
                );
              }

              if (!businessSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final businessIndex = _buildBusinessIndex(
                businessSnapshot.data!.docs,
              );

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, orderSnapshot) {
                  if (orderSnapshot.hasError) {
                    return const Center(
                      child: Text('تعذر تحميل بيانات الطلبات.'),
                    );
                  }

                  if (!orderSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final rows = _calculateRows(
                    orders: orderSnapshot.data!.docs,
                    businesses: businessIndex,
                  );

                  return _buildAccountingBody(
                    rows,
                    orderSnapshot.data!.docs,
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    final auctionContent = Column(
      children: [
        _buildPeriodSelector(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('auction_sales')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('تعذر تحميل عمليات بيع المزاد.'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final sales = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final rawDate = data['createdAt'] ?? data['updatedAt'];
                final accountingDate = rawDate is Timestamp ? rawDate : null;

                return _isInsideSelectedPeriod(accountingDate);
              }).toList();

              final totalSales = sales.fold<double>(
                0,
                (total, doc) => total + _toDouble(doc.data()['salePrice']),
              );

              final totalCommission = sales.fold<double>(
                0,
                (total, doc) =>
                    total + _toDouble(doc.data()['commissionAmount']),
              );

              final receivedCommission = sales
                  .where(
                    (doc) => doc.data()['commissionPaid'] == true,
                  )
                  .fold<double>(
                    0,
                    (total, doc) =>
                        total +
                        _toDouble(
                          doc.data()['commissionAmount'],
                        ),
                  );

              final pendingCommission = totalCommission - receivedCommission;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'ملخص مزاد $selectedPeriod',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: 'عمليات البيع',
                            value: '${sales.length}',
                            icon: Icons.gavel_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryCard(
                            title: 'قيمة المبيعات',
                            value: '${totalSales.toStringAsFixed(2)} ₪',
                            icon: Icons.payments_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: 'عمولة بركة',
                            value: '${totalCommission.toStringAsFixed(2)} ₪',
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryCard(
                            title: 'عمولة مستلمة',
                            value: '${receivedCommission.toStringAsFixed(2)} ₪',
                            icon: Icons.verified_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _summaryCard(
                      title: 'عمولة بانتظار الاستلام',
                      value: '${pendingCommission.toStringAsFixed(2)} ₪',
                      icon: Icons.hourglass_bottom_rounded,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'طلبات المزاد',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (sales.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'لا توجد عمليات بيع مزاد ضمن هذه الفترة.',
                          ),
                        ),
                      )
                    else
                      ...sales.map((doc) {
                        final data = doc.data();
                        final paid = data['commissionPaid'] == true;

                        final itemName =
                            data['itemName']?.toString().trim().isNotEmpty ==
                                    true
                                ? data['itemName'].toString().trim()
                                : 'سلعة مزاد';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: paid
                                          ? const Color(0xFFE7F7ED)
                                          : const Color(0xFFFFF3D8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      paid
                                          ? 'تم استلام العمولة'
                                          : 'بانتظار العمولة',
                                      style: TextStyle(
                                        color: paid
                                            ? const Color(0xFF167A45)
                                            : const Color(0xFF9A6200),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'سعر البيع: ${_toDouble(data['salePrice']).toStringAsFixed(2)} ₪',
                              ),
                              Text(
                                'عمولة بركة: ${_toDouble(data['commissionAmount']).toStringAsFixed(2)} ₪',
                              ),
                              Text(
                                'حالة العملية: ${data['status'] ?? 'pending_commission'}',
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F6F2),
          appBar: AppBar(
            backgroundColor: const Color(0xFF102A43),
            foregroundColor: Colors.white,
            centerTitle: true,
            title: const Text(
              'المحاسبة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: const TabBar(
              labelColor: Color(0xFFFFC928),
              unselectedLabelColor: Colors.white70,
              indicatorColor: Color(0xFFFFC928),
              tabs: [
                Tab(
                  icon: Icon(Icons.storefront_rounded),
                  text: 'طلبات المحلات',
                ),
                Tab(
                  icon: Icon(Icons.gavel_rounded),
                  text: 'طلبات المزاد',
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              storesContent,
              auctionContent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      'اليوم',
      'الأسبوع',
      'الشهر',
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        14,
      ),
      child: Row(
        children: periods.map((period) {
          final selected = selectedPeriod == period;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    selectedPeriod = period;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFC928)
                        : const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFF102A43)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountingBody(
    List<_BusinessAccountingRow> rows,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final totalSales = rows.fold<double>(
      0,
      (total, row) => total + row.sales,
    );

    final totalCommission = rows.fold<double>(
      0,
      (total, row) => total + row.commissionAmount,
    );

    final totalBusinessNet = totalSales - totalCommission;

    final totalOrders = rows.fold<int>(
      0,
      (total, row) => total + row.orderCount,
    );

    const driverCommissionRate = 10.0;

    final driverOrders = orders.where((order) {
      final data = order.data();

      final status = data['status']?.toString().trim().toLowerCase() ?? '';

      if (!const {
        'delivered',
        'completed',
        'finished',
      }.contains(status)) {
        return false;
      }

      final driverId = data['driverId']?.toString().trim() ?? '';
      if (driverId.isEmpty) {
        return false;
      }

      final rawDate =
          data['deliveredAt'] ?? data['updatedAt'] ?? data['createdAt'];

      final accountingDate = rawDate is Timestamp ? rawDate : null;

      return _isInsideSelectedPeriod(accountingDate);
    }).toList();

    final driverCollections = driverOrders.fold<double>(
      0,
      (total, order) => total + _toDouble(order.data()['deliveryFee']),
    );

    final driverCommission = driverCollections * driverCommissionRate / 100;

    final driverNet = driverCollections - driverCommission;

    final totalBarakahRevenue = totalCommission + driverCommission;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'ملخص $selectedPeriod',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'الطلبات المسلّمة',
                  value: '$totalOrders',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  title: 'مبيعات المحلات',
                  value: '${totalSales.toStringAsFixed(2)} ₪',
                  icon: Icons.point_of_sale_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'عمولة بركة',
                  value: '${totalCommission.toStringAsFixed(2)} ₪',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  title: 'صافي المحلات',
                  value: '${totalBusinessNet.toStringAsFixed(2)} ₪',
                  icon: Icons.storefront_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFC928).withOpacity(.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      color: Color(0xFF102A43),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'محاسبة السائقين',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        title: 'توصيلات السائقين',
                        value: '${driverOrders.length}',
                        icon: Icons.local_shipping_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        title: 'تحصيل التوصيل',
                        value: '${driverCollections.toStringAsFixed(2)} ₪',
                        icon: Icons.payments_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        title: 'عمولة بركة 10%',
                        value: '${driverCommission.toStringAsFixed(2)} ₪',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        title: 'صافي السائقين',
                        value: '${driverNet.toStringAsFixed(2)} ₪',
                        icon: Icons.person_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF102A43),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'إجمالي دخل بركة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${totalBarakahRevenue.toStringAsFixed(2)} ₪',
                  style: const TextStyle(
                    color: Color(0xFFFFC928),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'حسابات المحلات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF102A43),
                  ),
                ),
              ),
              Text(
                '${rows.length} محل',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _buildEmptyState()
          else
            ...rows.map(
              (row) => _buildBusinessCard(row),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC928).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A43),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(
    _BusinessAccountingRow row,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC928),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: Color(0xFF102A43),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.orderCount} طلب مسلّم • ${row.itemCount} قطعة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC928).withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${row.commissionRate.toStringAsFixed(row.commissionRate % 1 == 0 ? 0 : 1)}%',
                  style: const TextStyle(
                    color: Color(0xFF102A43),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _businessAmount(
                  'المبيعات',
                  '${row.sales.toStringAsFixed(2)} ₪',
                ),
              ),
              Expanded(
                child: _businessAmount(
                  'عمولة بركة',
                  '${row.commissionAmount.toStringAsFixed(2)} ₪',
                ),
              ),
              Expanded(
                child: _businessAmount(
                  'صافي المحل',
                  '${row.businessNet.toStringAsFixed(2)} ₪',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showBusinessDetails(row);
              },
              icon: const Icon(
                Icons.visibility_outlined,
              ),
              label: const Text(
                'عرض كشف الحساب',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF102A43),
                side: const BorderSide(
                  color: Color(0xFF102A43),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessAmount(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF102A43),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 55,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد طلبات مسلّمة في هذه الفترة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تظهر المحاسبة تلقائياً عند تغيير حالة الطلب إلى "تم التسليم".',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showBusinessDetails(
    _BusinessAccountingRow row,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    row.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'كشف حساب $selectedPeriod',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _detailRow(
                    'عدد الطلبات المسلّمة',
                    '${row.orderCount}',
                  ),
                  _detailRow(
                    'عدد القطع',
                    '${row.itemCount}',
                  ),
                  _detailRow(
                    'إجمالي المبيعات',
                    '${row.sales.toStringAsFixed(2)} ₪',
                  ),
                  _detailRow(
                    'نسبة عمولة بركة',
                    '${row.commissionRate.toStringAsFixed(1)}%',
                  ),
                  _detailRow(
                    'عمولة بركة',
                    '${row.commissionAmount.toStringAsFixed(2)} ₪',
                  ),
                  _detailRow(
                    'صافي المحل',
                    '${row.businessNet.toStringAsFixed(2)} ₪',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),
                      label: const Text(
                        'إغلاق',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC928),
                        foregroundColor: const Color(0xFF102A43),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A43),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInfo {
  const _BusinessInfo({
    required this.id,
    required this.title,
    required this.commissionRate,
  });

  final String id;
  final String title;
  final double commissionRate;
}

class _BusinessAccountingRow {
  _BusinessAccountingRow({
    required this.businessId,
    required this.title,
    required double commissionRate,
  }) : _fallbackCommissionRate = commissionRate;

  final String businessId;
  final String title;
  final double _fallbackCommissionRate;

  double sales = 0;
  double commission = 0;
  int itemCount = 0;

  final Set<String> orderIds = {};

  int get orderCount => orderIds.length;

  double get commissionRate =>
      sales > 0 ? commission / sales * 100 : _fallbackCommissionRate;

  double get commissionAmount => commission;

  double get businessNet => sales - commissionAmount;
}
