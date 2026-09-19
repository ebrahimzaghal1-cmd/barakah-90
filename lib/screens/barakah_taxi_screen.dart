import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/taxi_booking_section.dart';

class BarakahTaxiScreen extends StatelessWidget {
  const BarakahTaxiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_taxi_rounded,
              color: Colors.amber,
            ),
            SizedBox(width: 8),
            Text(
              'تكسي بركة',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD83D),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: AppTheme.navy,
                      child: Icon(
                        Icons.local_taxi_rounded,
                        color: Color(0xFFFFD83D),
                        size: 34,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تكسي بركة',
                            style: TextStyle(
                              color: AppTheme.navy,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'اطلب سيارتك من بركة مباشرة وبخصوصية',
                            style: TextStyle(
                              color: Color(0xFF26354D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              TaxiBookingSection(),
            ],
          ),
        ),
      ),
    );
  }
}
