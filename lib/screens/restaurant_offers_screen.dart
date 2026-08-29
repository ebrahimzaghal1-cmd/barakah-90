import 'package:flutter/material.dart';

class RestaurantOffersScreen extends StatelessWidget {
  const RestaurantOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6EE),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'عروض المطاعم',
          style: TextStyle(
            color: Color(0xFF172B4D),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF172B4D),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/offers/restaurants_offers.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.local_offer_rounded,
                color: Color(0xFF9A7600),
              ),
              SizedBox(width: 8),
              Text(
                'أحدث عروض المطاعم',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172B4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'ستظهر هنا عروض المطاعم التي يتم إضافتها من لوحة الإدارة.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
