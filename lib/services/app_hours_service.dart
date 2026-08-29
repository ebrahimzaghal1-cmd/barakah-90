import 'package:cloud_firestore/cloud_firestore.dart';

class AppHoursStatus {
  const AppHoursStatus({
    required this.isOpen,
    required this.isTemporarilyClosed,
    required this.openingTime,
    required this.closingTime,
    required this.title,
    required this.detail,
  });

  final bool isOpen;
  final bool isTemporarilyClosed;
  final String openingTime;
  final String closingTime;
  final String title;
  final String detail;
}

class AppHoursService {
  AppHoursService._();

  static final _document =
      FirebaseFirestore.instance.collection('app_settings').doc('app_hours');

  static Stream<AppHoursStatus?> watch() =>
      _document.snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : resolve(data);
      });

  static Future<AppHoursStatus?> fetch() async {
    final snapshot = await _document.get();
    final data = snapshot.data();
    return data == null ? null : resolve(data);
  }

  static AppHoursStatus? resolve(
    Map<String, dynamic> data, {
    DateTime? currentTime,
  }) {
    final openingTime = data['openingTime']?.toString().trim() ?? '10:00';
    final closingTime = data['closingTime']?.toString().trim() ?? '03:00';
    final openMinutes = _parseTime(openingTime);
    final closeMinutes = _parseTime(closingTime);

    if (openMinutes == null || closeMinutes == null) return null;

    final now = currentTime ?? DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final temporarilyClosed = data['temporarilyClosed'] == true;
    final enabledDays = data['enabledDays'];

    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    bool dayEnabled(String key) {
      if (enabledDays is Map) return enabledDays[key] != false;
      return true;
    }

    final todayKey = dayKeys[now.weekday - 1];
    final yesterdayKey = dayKeys[(now.weekday + 5) % 7];
    final crossesMidnight = closeMinutes <= openMinutes;

    final isOpen = !temporarilyClosed &&
        (crossesMidnight
            ? (dayEnabled(todayKey) && nowMinutes >= openMinutes) ||
                (dayEnabled(yesterdayKey) && nowMinutes < closeMinutes)
            : dayEnabled(todayKey) &&
                nowMinutes >= openMinutes &&
                nowMinutes < closeMinutes);

    final closedMessage = data['closedMessage']?.toString().trim() ?? '';
    final title = isOpen
        ? 'بركة مفتوحة الآن'
        : temporarilyClosed
            ? 'بركة مغلقة مؤقتًا'
            : 'بركة مغلقة الآن';
    final detail = isOpen
        ? 'نستقبل الطلبات حتى الساعة $closingTime.'
        : closedMessage.isNotEmpty
            ? closedMessage
            : 'نستقبل الطلبات من الساعة $openingTime حتى $closingTime.';

    return AppHoursStatus(
      isOpen: isOpen,
      isTemporarilyClosed: temporarilyClosed,
      openingTime: openingTime,
      closingTime: closingTime,
      title: title,
      detail: detail,
    );
  }

  static int? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }
}
