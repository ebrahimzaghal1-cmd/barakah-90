import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_manage_restaurants.dart';
import 'admin_taxi_office_details_screen.dart';

class AdminTaxiOfficesScreen extends StatefulWidget {
  const AdminTaxiOfficesScreen({super.key});

  @override
  State<AdminTaxiOfficesScreen> createState() => _AdminTaxiOfficesScreenState();
}

class _AdminTaxiOfficesScreenState extends State<AdminTaxiOfficesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _first(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _value(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = 'غير مضاف',
  }) {
    final value = _first(data, keys);
    return value.isEmpty ? fallback : value;
  }

  bool _isTaxiOffice(Map<String, dynamic> data) {
    final type = _first(data, [
      'itemType',
      'type',
      'merchantType',
      'businessType',
      'categoryType',
    ]).toLowerCase();

    if (type == 'taxi' || type == 'taxi_office') return true;

    final text = [
      data['businessName'],
      data['name'],
      data['title'],
      data['storeName'],
      data['businessCategory'],
      data['category'],
      data['activityType'],
      data['activity'],
      data['description'],
    ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

    return text.contains('taxi') || text.contains('تكسي');
  }

  String _name(Map<String, dynamic> data) {
    return _value(
      data,
      ['businessName', 'name', 'title', 'storeName'],
      fallback: 'مكتب تكسي بركة',
    );
  }

  String _owner(Map<String, dynamic> data) {
    return _value(data, [
      'ownerName',
      'managerName',
      'responsibleName',
      'contactName',
    ]);
  }

  String _phone(Map<String, dynamic> data) {
    return _value(data, [
      'phone',
      'phoneNumber',
      'ownerPhone',
      'businessPhone',
    ]);
  }

  String _area(Map<String, dynamic> data) {
    return _value(data, ['area', 'city', 'address', 'locationName']);
  }

  String _contract(Map<String, dynamic> data) {
    return _first(data, [
      'contractUrl',
      'contractPdfUrl',
      'agreementPdfUrl',
      'pdfUrl',
    ]);
  }

  String _status(Map<String, dynamic> data) {
    final status =
        _first(data, ['status', 'businessStatus', 'state']).toLowerCase();

    if (data['disabled'] == true || data['isActive'] == false) {
      return 'موقوف';
    }

    if (status == 'approved' || status == 'active' || status == 'open') {
      return 'مفعل';
    }

    if (status == 'pending' || status == 'review') {
      return 'بانتظار المراجعة';
    }

    if (status == 'rejected') return 'مرفوض';

    return 'قيد التجهيز';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'مفعل':
        return const Color(0xFF138A5B);
      case 'موقوف':
      case 'مرفوض':
        return const Color(0xFFC23B3B);
      case 'بانتظار المراجعة':
        return const Color(0xFFD18B00);
      default:
        return const Color(0xFF64748B);
    }
  }

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final data = doc.data();
    final haystack = [
      doc.id,
      _name(data),
      _owner(data),
      _phone(data),
      _area(data),
      _status(data),
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  bool _matchesFilter(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _status(data);
    final hasContract = _contract(data).isNotEmpty;

    switch (_filter) {
      case 'active':
        return status == 'مفعل';
      case 'pending':
        return status == 'بانتظار المراجعة' || status == 'قيد التجهيز';
      case 'no_contract':
        return !hasContract;
      case 'stopped':
        return status == 'موقوف' || status == 'مرفوض';
      default:
        return true;
    }
  }

  Future<_TaxiOfficeStats> _loadStats(String officeId) async {
    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('taxiBusinessId', isEqualTo: officeId)
          .get();

      final drivers = driversSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['role'] == 'driver' || data['taxiDriverEnabled'] == true;
      }).toList();

      final activeDrivers = drivers.where((doc) {
        final data = doc.data();
        return data['taxiDriverEnabled'] == true &&
            data['driverAvailable'] == true;
      }).length;

      final tripsSnapshot = await FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('businessId', isEqualTo: officeId)
          .get();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      var activeTrips = 0;
      var todayTrips = 0;

      for (final doc in tripsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';

        if (status == 'pending' ||
            status == 'dispatched' ||
            status == 'arrived' ||
            status == 'in_progress') {
          activeTrips++;
        }

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp && createdAt.toDate().isAfter(todayStart)) {
          todayTrips++;
        }
      }

      return _TaxiOfficeStats(
        drivers: drivers.length,
        activeDrivers: activeDrivers,
        activeTrips: activeTrips,
        todayTrips: todayTrips,
      );
    } catch (_) {
      return const _TaxiOfficeStats(
        drivers: 0,
        activeDrivers: 0,
        activeTrips: 0,
        todayTrips: 0,
      );
    }
  }

  Widget _hero({
    required int total,
    required int active,
    required int noContract,
    required int visible,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 20, 22, 14),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 18,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD166), Color(0xFFFFB703)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: Color(0xFF061826),
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تكسي بركة — مركز العمليات',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'إدارة المكاتب، العقود، السائقين، السيارات والرحلات من لوحة واحدة.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF138A5B),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'عمولة التكسي ثابتة: 0%',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiCard('إجمالي المكاتب', '$total', Icons.storefront_rounded),
              _kpiCard('مكاتب مفعلة', '$active', Icons.check_circle_rounded),
              _kpiCard('بدون عقد', '$noContract', Icons.description_outlined),
              _kpiCard('المعروض الآن', '$visible', Icons.visibility_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
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

  Widget _toolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 760;

          final search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: 'ابحث باسم المكتب، المالك، الهاتف أو المنطقة...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('all', 'الكل'),
              _filterChip('active', 'مفعلة'),
              _filterChip('pending', 'قيد المراجعة'),
              _filterChip('no_contract', 'بدون عقد'),
              _filterChip('stopped', 'موقوفة'),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 14),
                Expanded(child: filters),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              filters,
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: FontWeight.w900,
      ),
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    );
  }

  Widget _officeTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            dataRowMinHeight: 74,
            dataRowMaxHeight: 84,
            columns: const [
              DataColumn(label: Text('المكتب')),
              DataColumn(label: Text('صاحب المكتب')),
              DataColumn(label: Text('التواصل')),
              DataColumn(label: Text('المنطقة')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('العقد')),
              DataColumn(label: Text('المؤشرات')),
              DataColumn(label: Text('إجراءات')),
            ],
            rows: docs.map((doc) {
              final data = doc.data();
              final name = _name(data);
              final owner = _owner(data);
              final phone = _phone(data);
              final area = _area(data);
              final status = _status(data);
              final hasContract = _contract(data).isNotEmpty;

              return DataRow(
                cells: [
                  DataCell(Text(name)),
                  DataCell(Text(owner)),
                  DataCell(Text(phone)),
                  DataCell(Text(area)),
                  DataCell(_statusBadge(status)),
                  DataCell(
                    _miniBadge(
                      hasContract ? 'مرفوع' : 'غير مرفوع',
                      hasContract
                          ? Icons.check_circle_rounded
                          : Icons.description_outlined,
                      hasContract
                          ? const Color(0xFF138A5B)
                          : const Color(0xFFD18B00),
                    ),
                  ),
                  DataCell(
                    FutureBuilder<_TaxiOfficeStats>(
                      future: _loadStats(doc.id),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ??
                            const _TaxiOfficeStats(
                              drivers: 0,
                              activeDrivers: 0,
                              activeTrips: 0,
                              todayTrips: 0,
                            );

                        return Text(
                          'سائقون ${stats.drivers} • رحلات نشطة ${stats.activeTrips}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        );
                      },
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showOfficeDetails(doc),
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('تفاصيل'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _showContractNotice(name),
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('العقد'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _officeCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Column(
      children: docs.map((doc) {
        final data = doc.data();
        final name = _name(data);
        final owner = _owner(data);
        final phone = _phone(data);
        final area = _area(data);
        final status = _status(data);
        final hasContract = _contract(data).isNotEmpty;

        return Container(
          margin: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3CD),
                    child: Icon(
                      Icons.local_taxi_rounded,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 14),
              _infoLine(Icons.person_rounded, 'صاحب المكتب', owner),
              _infoLine(Icons.phone_rounded, 'الهاتف', phone),
              _infoLine(Icons.location_on_rounded, 'المنطقة', area),
              _infoLine(
                Icons.description_rounded,
                'العقد',
                hasContract ? 'يوجد عقد PDF' : 'لا يوجد عقد مرفوع بعد',
              ),
              const Divider(height: 24),
              FutureBuilder<_TaxiOfficeStats>(
                future: _loadStats(doc.id),
                builder: (context, snapshot) {
                  final stats = snapshot.data ??
                      const _TaxiOfficeStats(
                        drivers: 0,
                        activeDrivers: 0,
                        activeTrips: 0,
                        todayTrips: 0,
                      );

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _smallStat('السائقون', '${stats.drivers}'),
                      _smallStat('متاحون', '${stats.activeDrivers}'),
                      _smallStat('رحلات نشطة', '${stats.activeTrips}'),
                      _smallStat('رحلات اليوم', '${stats.todayTrips}'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showOfficeDetails(doc),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('تفاصيل المكتب'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showContractNotice(name),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('العقد PDF'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusBadge(String label) {
    final color = _statusColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF334155)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  void _showContractNotice(String officeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'قسم عقود $officeName جاهز في الواجهة، وسنضيف توليد/رفع PDF في المرحلة التالية.',
        ),
      ),
    );
  }

  void _showOfficeDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminTaxiOfficeDetailsScreen(
          officeId: doc.id,
          initialData: doc.data(),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Text(
          'لا توجد مكاتب تكسي مطابقة للبحث أو الفلتر الحالي.',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'مكاتب تكسي بركة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminManageRestaurants(
                      itemType: 'taxi',
                      singularLabel: 'مكتب تكسي',
                      pluralLabel: 'مكاتب تكسي بركة',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('إضافة مكتب'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('items').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'تعذر تحميل مكاتب التكسي:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final taxiOffices = snapshot.data!.docs
                .where((doc) => _isTaxiOffice(doc.data()))
                .toList()
              ..sort((a, b) => _name(a.data()).compareTo(_name(b.data())));

            final activeCount = taxiOffices
                .where((doc) => _status(doc.data()) == 'مفعل')
                .length;

            final noContractCount = taxiOffices
                .where((doc) => _contract(doc.data()).isEmpty)
                .length;

            final visible = taxiOffices
                .where(_matchesSearch)
                .where(_matchesFilter)
                .toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                return ListView(
                  children: [
                    _hero(
                      total: taxiOffices.length,
                      active: activeCount,
                      noContract: noContractCount,
                      visible: visible.length,
                    ),
                    _toolbar(),
                    if (visible.isEmpty)
                      _emptyState()
                    else if (isWide)
                      _officeTable(visible)
                    else
                      _officeCards(visible),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TaxiOfficeStats {
  final int drivers;
  final int activeDrivers;
  final int activeTrips;
  final int todayTrips;

  const _TaxiOfficeStats({
    required this.drivers,
    required this.activeDrivers,
    required this.activeTrips,
    required this.todayTrips,
  });
}
