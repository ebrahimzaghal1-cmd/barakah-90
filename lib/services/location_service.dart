import 'package:geolocator/geolocator.dart';

class LocationService {
  static double distanceBetween(double startLatitude, double startLongitude,
          double endLatitude, double endLongitude) =>
      Geolocator.distanceBetween(
          startLatitude, startLongitude, endLatitude, endLongitude);

  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // هل GPS شغال؟
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('الـ GPS غير مفعل');
    }

    // الصلاحيات
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض الصلاحية');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('الصلاحية مرفوضة نهائيًا');
    }

    // جلب الموقع
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
