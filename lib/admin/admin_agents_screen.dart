import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_agent_finance_screen.dart';
import 'admin_agent_contract_panel.dart';
import 'admin_manage_agent_applications.dart';

class AdminAgentsScreen extends StatefulWidget {
  const AdminAgentsScreen({super.key});

  @override
  State<AdminAgentsScreen> createState() => _AdminAgentsScreenState();
}

class _AdminAgentsScreenState extends State<AdminAgentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String get _query => _searchController.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _searchBox(String hint) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
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
  }

  Widget _metric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
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

  bool _contains(Map<String, dynamic> data, String id) {
    if (_query.isEmpty) return true;

    final text = [
      id,
      data['fullName'],
      data['email'],
      data['phone'],
      data['area'],
      data['locationLabel'],
    ].whereType<Object>().join(' ').toLowerCase();

    return text.contains(_query);
  }

  Future<void> _openAgent(
    BuildContext context,
    String agentId,
    Map<String, dynamic> fallback,
  ) async {
    var data = fallback;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .get();

      if (snapshot.data() != null) {
        data = snapshot.data()!;
      }
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAgentDetailsScreen(
          agentId: agentId,
          initialData: data,
        ),
      ),
    );
  }

  Widget _agentCard(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final name = data['fullName']?.toString().trim().isNotEmpty == true
        ? data['fullName'].toString().trim()
        : document.id;

    final active = data['active'] == true && data['approved'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openAgent(context, document.id, data),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFFE7F7EF) : const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                active ? Icons.support_agent_rounded : Icons.person_off_rounded,
                color:
                    active ? const Color(0xFF138A5B) : const Color(0xFFC23B3B),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['area'] ?? 'منطقة غير مضافة'} • ${data['phone'] ?? 'هاتف غير مضاف'}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFFE7F7EF) : const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                active ? 'مفعلة' : 'متوقفة',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF138A5B)
                      : const Color(0xFFC23B3B),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }

  Widget _agentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('agents').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر تحميل الوسيطات.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data!.docs;
        final filtered = all
            .where((document) => _contains(
                  document.data(),
                  document.id,
                ))
            .toList()
          ..sort((a, b) {
            final left = a.data()['fullName']?.toString().toLowerCase() ?? '';
            final right = b.data()['fullName']?.toString().toLowerCase() ?? '';
            return left.compareTo(right);
          });

        final active = all.where((document) {
          final data = document.data();
          return data['active'] == true && data['approved'] == true;
        }).length;

        final inactive = all.length - active;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'كل الوسيطات',
                  '${all.length}',
                  Icons.groups_rounded,
                  const Color(0xFF2563EB),
                ),
                _metric(
                  'المفعلة',
                  '$active',
                  Icons.verified_rounded,
                  const Color(0xFF138A5B),
                ),
                _metric(
                  'المتوقفة',
                  '$inactive',
                  Icons.pause_circle_rounded,
                  const Color(0xFFC23B3B),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _searchBox('ابحثي باسم الوسيطة، المنطقة، الهاتف أو البريد'),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'لا توجد نتائج مطابقة.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map(
                (document) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _agentCard(context, document),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _pieceContains(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;

    final text = [
      data['agentName'],
      data['pieceCode'],
      data['name'],
      data['size'],
      data['color'],
      data['notes'],
    ].whereType<Object>().join(' ').toLowerCase();

    return text.contains(_query);
  }

  Widget _piecesSearchTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collectionGroup('pieces').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر البحث في القطع.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final pieces = snapshot.data!.docs
            .where((document) => _pieceContains(document.data()))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            _searchBox(
              'ابحثي بالوسيطة، كود القطعة، الاسم، المقاس، اللون أو الملاحظات',
            ),
            const SizedBox(height: 14),
            if (pieces.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'لا توجد قطع مطابقة.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            else
              ...pieces.map((document) {
                final data = document.data();
                final agentId = data['agentId']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: agentId.isEmpty
                        ? null
                        : () => _openAgent(
                              context,
                              agentId,
                              <String, dynamic>{
                                'fullName': data['agentName'],
                              },
                            ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                              color: const Color(0xFFFFF7D6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF9A6A00),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name']?.toString() ?? 'قطعة',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${data['pieceCode'] ?? '-'} • ${data['agentName'] ?? 'وسيطة غير معروفة'}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'المقاس: ${data['size'] ?? '-'} • اللون: ${data['color'] ?? '-'}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F2747),
            foregroundColor: Colors.white,
            title: const Text(
              'إدارة الوسيطات',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            centerTitle: true,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFFB8C4D4),
              indicatorColor: Color(0xFFFFD54F),
              tabs: [
                Tab(
                  icon: Icon(Icons.support_agent_rounded),
                  text: 'الوسيطات',
                ),
                Tab(
                  icon: Icon(Icons.inventory_2_rounded),
                  text: 'البحث في القطع',
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                color: const Color(0xFFF7F8FA),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminManageAgentApplications(),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('طلبات الانضمام'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminAgentFinanceScreen(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.account_balance_wallet_rounded,
                      ),
                      label: const Text('المالية والمستحقات'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _agentsTab(),
                    _piecesSearchTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminAgentDetailsScreen extends StatefulWidget {
  final String agentId;
  final Map<String, dynamic> initialData;

  const AdminAgentDetailsScreen({
    super.key,
    required this.agentId,
    required this.initialData,
  });

  @override
  State<AdminAgentDetailsScreen> createState() =>
      _AdminAgentDetailsScreenState();
}

class _AdminAgentDetailsScreenState extends State<AdminAgentDetailsScreen> {
  final TextEditingController _pieceSearchController = TextEditingController();

  @override
  void dispose() {
    _pieceSearchController.dispose();
    super.dispose();
  }

  String _value(
    Map<String, dynamic> data,
    String key, {
    String fallback = 'غير مضاف',
  }) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  Widget _field(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF334155),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 145,
            child: Text(
              label,
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

  Widget _overview(Map<String, dynamic> data) {
    final active = data['active'] == true && data['approved'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFE7F7EF)
                          : const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: active
                          ? const Color(0xFF138A5B)
                          : const Color(0xFFC23B3B),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _value(
                            data,
                            'fullName',
                            fallback: widget.agentId,
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          active ? 'وسيطة مفعلة' : 'وسيطة متوقفة',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF138A5B)
                                : const Color(0xFFC23B3B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _field(
                Icons.badge_outlined,
                'معرف الوسيطة',
                widget.agentId,
              ),
              _field(
                Icons.email_outlined,
                'البريد',
                _value(data, 'email'),
              ),
              _field(
                Icons.phone_outlined,
                'الهاتف',
                _value(data, 'phone'),
              ),
              _field(
                Icons.badge_rounded,
                'رقم الهوية',
                _value(data, 'nationalId'),
              ),
              _field(
                Icons.location_city_rounded,
                'المنطقة',
                _value(data, 'area'),
              ),
              _field(
                Icons.location_on_outlined,
                'الموقع',
                _value(data, 'locationLabel'),
              ),
              _field(
                Icons.account_balance_wallet_outlined,
                'طريقة المستحقات',
                _value(data, 'payoutMethod'),
              ),
              _field(
                Icons.payments_outlined,
                'بيانات الاستلام',
                _value(data, 'payoutAccount'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _newPieceCode() {
    final value =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();

    return 'BRK$value';
  }

  Future<void> _showPieceDialog(
    BuildContext context,
    Map<String, dynamic> agent, {
    DocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final editing = existing != null;
    final oldData = existing?.data() ?? const <String, dynamic>{};

    final formKey = GlobalKey<FormState>();

    final code = TextEditingController(
      text: editing
          ? oldData['pieceCode']?.toString() ?? existing.id
          : _newPieceCode(),
    );
    final name = TextEditingController(
      text: oldData['name']?.toString() ?? '',
    );
    final size = TextEditingController(
      text: oldData['size']?.toString() ?? '',
    );
    final color = TextEditingController(
      text: oldData['color']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: oldData['notes']?.toString() ?? '',
    );

    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;

              final cleanCode = code.text.trim().toUpperCase();

              if (!RegExp(r'^[A-Z0-9_-]{2,40}$').hasMatch(cleanCode)) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'كود القطعة يسمح بالأحرف الإنجليزية والأرقام و - و _ فقط.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);

              try {
                final pieces = FirebaseFirestore.instance
                    .collection('agents')
                    .doc(widget.agentId)
                    .collection('pieces');

                final ref = pieces.doc(cleanCode);

                if (!editing) {
                  final duplicate = await ref.get();

                  if (duplicate.exists) {
                    throw StateError(
                      'هذا الكود مستخدم مسبقًا لدى هذه الوسيطة.',
                    );
                  }

                  await ref.set({
                    'agentId': widget.agentId,
                    'agentName':
                        _value(agent, 'fullName', fallback: widget.agentId),
                    'pieceCode': cleanCode,
                    'name': name.text.trim(),
                    'size': size.text.trim(),
                    'color': color.text.trim(),
                    'notes': notes.text.trim(),
                    'active': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await existing.reference.update({
                    'agentName':
                        _value(agent, 'fullName', fallback: widget.agentId),
                    'name': name.text.trim(),
                    'size': size.text.trim(),
                    'color': color.text.trim(),
                    'notes': notes.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (this.context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        editing
                            ? 'تم تعديل القطعة بنجاح ✅'
                            : 'تمت إضافة القطعة بنجاح ✅',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (this.context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        error is StateError
                            ? error.message.toString()
                            : 'تعذر حفظ القطعة: $error',
                      ),
                    ),
                  );
                }

                setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              title: Text(
                editing ? 'تعديل القطعة' : 'إضافة قطعة للوسيطة',
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: code,
                          enabled: !editing && !saving,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'كود القطعة',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                          ),
                          validator: (value) {
                            final clean = value?.trim() ?? '';

                            if (clean.isEmpty) {
                              return 'أدخلي كود القطعة';
                            }

                            if (!RegExp(r'^[A-Za-z0-9_-]{2,40}$')
                                .hasMatch(clean)) {
                              return 'استخدمي أحرفًا وأرقامًا فقط';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: name,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'اسم / وصف القطعة',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'أدخلي اسم القطعة'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: size,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'النمرة / المقاس',
                            prefixIcon: Icon(Icons.straighten_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: color,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'اللون',
                            prefixIcon: Icon(Icons.palette_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notes,
                          enabled: !saving,
                          maxLines: 4,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(editing ? 'حفظ التعديل' : 'إضافة القطعة'),
                ),
              ],
            );
          },
        );
      },
    );

    code.dispose();
    name.dispose();
    size.dispose();
    color.dispose();
    notes.dispose();
  }

  Future<void> _deletePiece(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف القطعة؟'),
        content: Text(
          'سيتم حذف القطعة ${document.data()?['pieceCode'] ?? document.id} نهائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC23B3B),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await document.reference.delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف القطعة.'),
        ),
      );
    }
  }

  bool _matchesPiece(Map<String, dynamic> data) {
    final query = _pieceSearchController.text.trim().toLowerCase();

    if (query.isEmpty) return true;

    final text = [
      data['pieceCode'],
      data['name'],
      data['size'],
      data['color'],
      data['notes'],
    ].whereType<Object>().join(' ').toLowerCase();

    return text.contains(query);
  }

  Widget _pieces(Map<String, dynamic> agent) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentId)
          .collection('pieces')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر تحميل القطع.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs
            .where((document) => _matchesPiece(document.data()))
            .toList()
          ..sort((a, b) {
            final left = a.data()['pieceCode']?.toString() ?? a.id;
            final right = b.data()['pieceCode']?.toString() ?? b.id;
            return left.compareTo(right);
          });

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _pieceSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'بحث بالكود، الاسم، المقاس، اللون أو الملاحظات',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showPieceDialog(context, agent),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة قطعة'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${documents.length} قطعة ظاهرة',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (documents.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'لا توجد قطع حتى الآن.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            else
              ...documents.map((document) {
                final data = document.data();
                final active = data['active'] != false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7D6),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF9A6A00),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _value(
                                    data,
                                    'name',
                                    fallback: 'قطعة',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  'الكود: ${data['pieceCode'] ?? document.id}',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: active,
                            onChanged: (value) async {
                              await document.reference.update({
                                'active': value,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'المقاس: ${_value(data, 'size')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'اللون: ${_value(data, 'color')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((data['notes']?.toString().trim() ?? '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            data['notes'].toString(),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showPieceDialog(
                              context,
                              agent,
                              existing: document,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFC23B3B),
                            ),
                            onPressed: () => _deletePiece(context, document),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('حذف'),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.initialData;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: DefaultTabController(
            length: 3,
            child: Scaffold(
              backgroundColor: const Color(0xFFF7F8FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F2747),
                foregroundColor: Colors.white,
                title: Text(
                  _value(
                    data,
                    'fullName',
                    fallback: 'تفاصيل الوسيطة',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xFFB8C4D4),
                  indicatorColor: Color(0xFFFFD54F),
                  tabs: [
                    Tab(
                      icon: Icon(Icons.dashboard_outlined),
                      text: 'البيانات',
                    ),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined),
                      text: 'القطع',
                    ),
                    Tab(
                      icon: Icon(Icons.description_outlined),
                      text: 'العقد',
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _overview(data),
                  _pieces(data),
                  AdminAgentContractPanel(
                    agentId: widget.agentId,
                    agentName: _value(
                      data,
                      'fullName',
                      fallback: widget.agentId,
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
}
