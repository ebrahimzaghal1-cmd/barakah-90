import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'admin_appointments_accounting_screen.dart';
import 'admin_business_accounting_screen.dart';
import 'admin_manage_orders.dart';

class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          title: const Text(
            'مركز العمليات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        body: Column(
          children: [
            Container(
              height: 132,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [Color(0xFF122447), Color(0xFF1E4275)],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PositionedDirectional(
                    end: -12,
                    top: -32,
                    bottom: -30,
                    width: 230,
                    child: Opacity(
                      opacity: .20,
                      child: Image.asset(
                        'assets/images/barakah_header_bunny.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'كل عملياتك في مكان واحد',
                          style: TextStyle(
                            color: AppTheme.coolYellow,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(
                          width: 260,
                          child: Text(
                            'تابعي الطلبات خطوة بخطوة، ثم راجعي المبيعات والعمولات مباشرة.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16122447),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.coolYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: AppTheme.navy,
                unselectedLabelColor: AppTheme.navy.withOpacity(.55),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.receipt_long_rounded),
                    text: 'الطلبات',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_rounded),
                    text: 'المحاسبة',
                  ),
                  Tab(
                    icon: Icon(Icons.event_available_rounded),
                    text: 'الحجوزات',
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  AdminManageOrders(embedded: true),
                  AdminBusinessAccountingScreen(embedded: true),
                  AdminAppointmentsAccountingScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
