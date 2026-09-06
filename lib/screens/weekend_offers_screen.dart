import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/advertisement_banner.dart';
import '../widgets/barakah_brand.dart';

class WeekendOffersScreen extends StatelessWidget {
  const WeekendOffersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFFFCF5),
        appBar: AppBar(
          title: const Text(
            'عروض نهاية الأسبوع',
            style: TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppTheme.navy),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    SizedBox(width: 170, child: BarakahBrandName(light: true)),
                    SizedBox(height: 12),
                    Text(
                      'كل عروض المطاعم الخاصة بنهاية الأسبوع في مكان واحد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SponsoredAdsFeed(
                placement: 'weekend_offers',
                title: 'العروض المتاحة الآن',
                maxItems: 50,
                includeGlobal: false,
                emptyMessage:
                    'لا توجد عروض لنهاية الأسبوع الآن. ستظهر هنا فور إضافتها من لوحة الإدارة.',
              ),
            ],
          ),
        ),
      );
}
