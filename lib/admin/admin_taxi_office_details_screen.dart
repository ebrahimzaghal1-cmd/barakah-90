import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/admin_pdf_picker.dart';
import '../services/taxi_driver_admin_service.dart';

class AdminTaxiOfficeDetailsScreen extends StatelessWidget {
  final String officeId;
  final Map<String, dynamic> initialData;

  const AdminTaxiOfficeDetailsScreen({
    super.key,
    required this.officeId,
    required this.initialData,
  });

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

  Widget _statusBadge(String label) {
    final color = _statusColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 14),
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF334155)),
          const SizedBox(width: 9),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
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

  Widget _metric(String title, String value, IconData icon, Color color) {
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
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('taxiBusinessId', isEqualTo: officeId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _tripsStream() {
    return FirebaseFirestore.instance
        .collection('taxi_orders')
        .where('businessId', isEqualTo: officeId)
        .snapshots();
  }

  Widget _overview(Map<String, dynamic> office) {
    final status = _status(office);
    final contractUrl = _contract(office);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                children: [
                  Text(
                    _name(office),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 18),
              _field(Icons.badge_rounded, 'رقم المكتب', officeId),
              _field(Icons.person_rounded, 'صاحب المكتب', _owner(office)),
              _field(Icons.phone_rounded, 'رقم التواصل', _phone(office)),
              _field(Icons.location_on_rounded, 'المنطقة', _area(office)),
              _field(
                Icons.percent_rounded,
                'عمولة التكسي',
                '0% ثابتة — لا تدخل ضمن أرباح عمولات بركة',
              ),
              _field(
                Icons.description_rounded,
                'العقد',
                contractUrl.isEmpty ? 'غير مرفوع بعد' : 'يوجد عقد PDF',
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _driversStream(),
          builder: (context, driversSnapshot) {
            final drivers = driversSnapshot.data?.docs ?? [];
            final activeDrivers = drivers.where((doc) {
              final data = doc.data();
              return data['taxiDriverEnabled'] == true &&
                  data['driverAvailable'] == true;
            }).length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tripsStream(),
              builder: (context, tripsSnapshot) {
                final trips = tripsSnapshot.data?.docs ?? [];
                final activeTrips = trips.where((doc) {
                  final status = doc.data()['status']?.toString() ?? '';
                  return status == 'pending' ||
                      status == 'dispatched' ||
                      status == 'arrived' ||
                      status == 'in_progress';
                }).length;

                return _card(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metric(
                        'السائقون',
                        '${drivers.length}',
                        Icons.groups_rounded,
                        const Color(0xFF2563EB),
                      ),
                      _metric(
                        'المتاحون الآن',
                        '$activeDrivers',
                        Icons.check_circle_rounded,
                        const Color(0xFF138A5B),
                      ),
                      _metric(
                        'الرحلات النشطة',
                        '$activeTrips',
                        Icons.route_rounded,
                        const Color(0xFFD18B00),
                      ),
                      _metric(
                        'كل الرحلات',
                        '${trips.length}',
                        Icons.receipt_long_rounded,
                        const Color(0xFF0F172A),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadAssignableDrivers() async {
    final applications = await FirebaseFirestore.instance
        .collection('taxi_driver_applications')
        .where('status', isEqualTo: 'approved')
        .get();

    final users = FirebaseFirestore.instance.collection('users');

    final candidates = await Future.wait(
      applications.docs.map((application) async {
        final applicationData = application.data();

        final fullyVerified = applicationData['identityVerified'] == true &&
            applicationData['driverLicenseVerified'] == true &&
            applicationData['vehicleDocumentsVerified'] == true &&
            applicationData['payoutVerified'] == true &&
            applicationData['acceptedDriverTerms'] == true &&
            applicationData['acceptedPrivacyPolicy'] == true;

        if (!fullyVerified) {
          return null;
        }

        final userDoc = await users.doc(application.id).get();
        final userData = userDoc.data() ?? <String, dynamic>{};

        final currentOffice =
            userData['taxiBusinessId']?.toString().trim() ?? '';

        // لا نظهر سائقي مكتب آخر ولا السائق المرتبط أصلًا بهذا المكتب.
        if (currentOffice.isNotEmpty) {
          return null;
        }

        return <String, dynamic>{
          'uid': application.id,
          'name': _value(
            applicationData,
            ['fullName', 'name', 'displayName'],
            fallback: application.id,
          ),
          'phone': _value(
            applicationData,
            ['phone', 'phoneNumber'],
          ),
          'vehicle': _value(
            applicationData,
            ['vehicle'],
          ),
        };
      }),
    );

    return candidates.whereType<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) => (a['name']?.toString() ?? '')
            .compareTo(b['name']?.toString() ?? ''),
      );
  }

  String _driverStatus(Map<String, dynamic> data) {
    if (data['taxiDriverEnabled'] == false) {
      return 'موقوف';
    }

    if (data['driverBusy'] == true ||
        (data['activeOrderId']?.toString().trim().isNotEmpty ?? false)) {
      return 'في رحلة';
    }

    if (data['driverAvailable'] == true) {
      return 'متاح';
    }

    return 'غير متاح';
  }

  Color _driverStatusColor(String status) {
    switch (status) {
      case 'متاح':
        return const Color(0xFF138A5B);
      case 'في رحلة':
        return const Color(0xFF2563EB);
      case 'موقوف':
        return const Color(0xFFC23B3B);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _driverStatusBadge(String status) {
    final color = _driverStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showAssignDriverDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 4, 22, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة سائق معتمد للمكتب',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'تظهر هنا فقط طلبات السائقين المعتمدة وغير المرتبطة بمكتب تكسي آخر.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadAssignableDrivers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'تعذر تحميل السائقين:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final drivers = snapshot.data ?? const [];

                        if (drivers.isEmpty) {
                          return const Center(
                            child: Text(
                              'لا يوجد سائقون معتمدون غير مرتبطين بمكتب حاليًا.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final driver = drivers[index];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver['name']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          driver['phone']?.toString() ??
                                              'غير مضاف',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Text(
                                          driver['vehicle']?.toString() ??
                                              'غير مضافة',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => _assignDriverToOffice(
                                      sheetContext,
                                      driver,
                                    ),
                                    child: const Text('إضافة'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
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

  Future<void> _assignDriverToOffice(
    BuildContext context,
    Map<String, dynamic> driver,
  ) async {
    final uid = driver['uid']?.toString() ?? '';
    if (uid.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text('جاري ربط السائق بالمكتب...'),
            ),
          ],
        ),
      ),
    );

    try {
      await TaxiDriverAdminService.instance.assignDriver(
        driverUid: uid,
        businessId: officeId,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // إغلاق نافذة اختيار السائق.
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت إضافة ${driver['name'] ?? 'السائق'} إلى المكتب بنجاح ✅',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر ربط السائق بالمكتب: $error'),
          ),
        );
      }
    }
  }

  Future<void> _removeDriverFromOffice(
    BuildContext context,
    String driverUid,
    String driverName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إزالة السائق من المكتب'),
          content: Text(
            'هل تريدين إزالة $driverName من هذا المكتب؟\n\n'
            'لن يتم حذف حساب السائق أو طلب تسجيله، فقط سيتم فك ارتباطه بالمكتب.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إزالة السائق'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await TaxiDriverAdminService.instance.removeDriver(
        driverUid: driverUid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم فك ارتباط السائق بالمكتب بنجاح ✅'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إزالة السائق من المكتب: $error'),
          ),
        );
      }
    }
  }

  Widget _drivers() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _card(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سائقو المكتب',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${docs.length} سائق مرتبط بهذا المكتب',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _showAssignDriverDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة سائق معتمد'),
                  ),
                ],
              ),
            ),
            if (docs.isEmpty)
              _card(
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text(
                      'لا يوجد سائقون مرتبطون بهذا المكتب حتى الآن.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();

                final name = _value(
                  data,
                  [
                    'displayName',
                    'name',
                    'fullName',
                    'driverName',
                  ],
                  fallback: doc.id,
                );

                final phone = _value(
                  data,
                  [
                    'driverPhone',
                    'phone',
                    'phoneNumber',
                  ],
                );

                final vehicle = _value(
                  data,
                  [
                    'driverVehicle',
                    'vehicleInfo',
                    'vehicle',
                    'carInfo',
                  ],
                );

                final status = _driverStatus(data);

                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _driverStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _field(
                        Icons.local_taxi_rounded,
                        'السيارة',
                        vehicle,
                      ),
                      _field(
                        Icons.badge_rounded,
                        'معرف السائق',
                        doc.id,
                      ),
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _removeDriverFromOffice(
                            context,
                            doc.id,
                            name,
                          ),
                          icon: const Icon(
                            Icons.link_off_rounded,
                            color: Color(0xFFC23B3B),
                          ),
                          label: const Text(
                            'فك الارتباط بالمكتب',
                            style: TextStyle(
                              color: Color(0xFFC23B3B),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _vehicles() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final vehicles = snapshot.data!.docs.map((doc) {
          final data = doc.data();
          return {
            'driver': _value(data, ['displayName', 'name', 'fullName']),
            'vehicle': _value(data, [
              'taxiDriverVehicle',
              'driverVehicle',
              'vehicleInfo',
              'vehicle',
              'carInfo'
            ]),
            'plate': _value(
                data, ['taxiDriverPlateNumber', 'plateNumber', 'vehiclePlate'],
                fallback: 'غير مضافة'),
            'color': _value(
                data, ['taxiDriverVehicleColor', 'vehicleColor', 'carColor'],
                fallback: 'غير مضاف'),
          };
        }).toList();

        if (vehicles.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد سيارات مرتبطة بسائقي هذا المكتب حتى الآن.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];

            return _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(
                      Icons.local_taxi_rounded, 'السيارة', vehicle['vehicle']!),
                  _field(Icons.person_rounded, 'السائق', vehicle['driver']!),
                  _field(Icons.confirmation_number_rounded, 'اللوحة',
                      vehicle['plate']!),
                  _field(Icons.palette_rounded, 'اللون', vehicle['color']!),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _trips() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tripsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            final aDate = aTime is Timestamp ? aTime.toDate() : DateTime(1970);
            final bDate = bTime is Timestamp ? bTime.toDate() : DateTime(1970);
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد رحلات لهذا المكتب حتى الآن.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            return _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    data['orderNumber']?.toString() ?? docs[index].id,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _field(Icons.person_rounded, 'العميل',
                      _value(data, ['customerName'])),
                  _field(Icons.phone_rounded, 'الهاتف',
                      _value(data, ['customerPhone'])),
                  _field(Icons.place_rounded, 'الركوب',
                      _value(data, ['pickupAddress'])),
                  _field(Icons.flag_rounded, 'الوجهة',
                      _value(data, ['destination'])),
                  _field(Icons.info_rounded, 'الحالة',
                      data['status']?.toString() ?? 'غير محددة'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateContractPdf(
    BuildContext context,
    Map<String, dynamic> office,
  ) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    final name = _name(office);
    final owner = _owner(office);
    final phone = _phone(office);
    final area = _area(office);
    final issuedAt = DateTime.now();

    final issuedAtText =
        '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}-${issuedAt.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(32),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
        ),
        build: (pdfContext) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.amber700,
                    width: 1.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      'عقد انضمام مكتب تكسي إلى منصة بركة',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'تكسي بركة',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Text(
              'بيانات المكتب',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfRow('اسم المكتب', name),
            _pdfRow('رقم المكتب الداخلي', officeId),
            _pdfRow('صاحب المكتب', owner),
            _pdfRow('رقم التواصل', phone),
            _pdfRow('المنطقة', area),
            _pdfRow('عمولة تكسي بركة', '0% ثابتة'),
            _pdfRow('تاريخ إصدار العقد', issuedAtText),
            pw.SizedBox(height: 24),
            pw.Text(
              'بنود أساسية',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfBullet(
                'يلتزم مكتب التكسي بتقديم خدمة آمنة ومحترمة لعملاء بركة.'),
            _pdfBullet(
                'يلتزم المكتب بتحديث بيانات السائقين والسيارات بشكل صحيح.'),
            _pdfBullet(
                'كل رحلة يتم تسجيلها داخل النظام لحفظ حقوق العميل والمكتب وبركة.'),
            _pdfBullet(
                'عمولة تكسي بركة الحالية ثابتة 0% ولا تدخل ضمن أرباح عمولات بركة.'),
            _pdfBullet(
                'أي تعديل على بيانات المكتب أو السائقين أو السيارات يجب أن يتم من خلال لوحة الإدارة المعتمدة.'),
            _pdfBullet(
                'يحق لإدارة بركة إيقاف المكتب أو السائق عند وجود مخالفة أو شكوى مثبتة.'),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureBox('توقيع إدارة بركة'),
                _signatureBox('توقيع صاحب المكتب'),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'barakah-taxi-contract-$officeId.pdf',
      onLayout: (_) async => pdf.save(),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز عقد PDF للطباعة.')),
      );
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _pdfBullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(text)),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(String title) {
    return pw.Container(
      width: 210,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 35),
          pw.Divider(),
          pw.Text(
            'التوقيع والختم',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadContractPdf(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('رفع العقد الموقع غير مفعل الآن'),
          content: const Text(
            'توليد وطباعة عقد PDF يعملان بشكل طبيعي.\n\n'
            'أما رفع العقد الموقع وحفظ رابطه داخل النظام فيحتاج تفعيل Firebase Storage من لوحة Firebase، وهذا يتطلب ترقية المشروع.\n\n'
            'حاليًا يمكنك توليد العقد، حفظه أو طباعته، ثم نفعّل الرفع لاحقًا عند تفعيل Storage.',
            textAlign: TextAlign.right,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تمام'),
            ),
          ],
        );
      },
    );
  }

  Widget _contractTab(BuildContext context, Map<String, dynamic> office) {
    final contractUrl = _contract(office);
    final hasContract = contractUrl.isNotEmpty;
    final contractFileName = _value(
      office,
      ['contractOriginalFileName'],
      fallback: 'غير مضاف',
    );
    final contractStoragePath = _value(
      office,
      ['contractStoragePath'],
      fallback: 'غير مضاف',
    );
    final contractStatus = _value(
      office,
      ['contractStatus'],
      fallback: hasContract ? 'uploaded' : 'غير مرفوع',
    );

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'عقد مكتب التكسي',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasContract
                      ? const Color(0xFFEFFAF3)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasContract
                        ? const Color(0xFFB7E4C7)
                        : const Color(0xFFF5D77A),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasContract
                              ? Icons.check_circle_rounded
                              : Icons.info_rounded,
                          color: hasContract
                              ? const Color(0xFF138A5B)
                              : const Color(0xFFD18B00),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasContract
                                ? 'العقد محفوظ ومرفوع لهذا المكتب.'
                                : 'لا يوجد عقد PDF مرفوع بعد. يمكنك توليد عقد للطباعة الآن، ورفع العقد الموقع يتطلب تفعيل Firebase Storage لاحقًا.',
                            style: TextStyle(
                              color: hasContract
                                  ? const Color(0xFF138A5B)
                                  : const Color(0xFF8A5A00),
                              fontWeight: FontWeight.w900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasContract) ...[
                      const SizedBox(height: 12),
                      _field(Icons.picture_as_pdf_rounded, 'اسم الملف',
                          contractFileName),
                      _field(Icons.cloud_done_rounded, 'حالة العقد',
                          contractStatus),
                      _field(Icons.folder_rounded, 'مسار التخزين',
                          contractStoragePath),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _generateContractPdf(context, office),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('توليد عقد PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _uploadContractPdf(context),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('رفع / استبدال العقد'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('items')
            .doc(officeId)
            .snapshots(),
        builder: (context, snapshot) {
          final office = snapshot.data?.data() ?? initialData;
          final name = _name(office);

          return DefaultTabController(
            length: 5,
            child: Scaffold(
              backgroundColor: const Color(0xFFF4F6FA),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                bottom: const TabBar(
                  isScrollable: true,
                  labelColor: Color(0xFF0F172A),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFFFFB703),
                  tabs: [
                    Tab(text: 'نظرة عامة'),
                    Tab(text: 'السائقون'),
                    Tab(text: 'السيارات'),
                    Tab(text: 'الرحلات'),
                    Tab(text: 'العقد PDF'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _overview(office),
                  _drivers(),
                  _vehicles(),
                  _trips(),
                  _contractTab(context, office),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
