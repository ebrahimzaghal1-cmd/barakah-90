class BusinessHoursStatus {
  const BusinessHoursStatus({
    required this.code,
    required this.label,
    required this.isAcceptingOrders,
    required this.minutesUntilChange,
  });

  final String code;
  final String label;
  final bool isAcceptingOrders;
  final int? minutesUntilChange;
}

class BusinessHoursService {
  static const List<String> _dayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  static BusinessHoursStatus resolve({
    required Map<String, dynamic> data,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    final businessStatus =
        data['businessStatus']?.toString().trim().toLowerCase() ?? 'open';

    if (businessStatus == 'closed') {
      return const BusinessHoursStatus(
        code: 'temporarily_closed',
        label: 'مغلق مؤقتًا',
        isAcceptingOrders: false,
        minutesUntilChange: null,
      );
    }

    if (businessStatus == 'busy') {
      return const BusinessHoursStatus(
        code: 'busy',
        label: 'مشغول',
        isAcceptingOrders: true,
        minutesUntilChange: null,
      );
    }

    final weekly = _weeklyHours(data);

    if (weekly != null) {
      return _resolveWeekly(
        data: data,
        weekly: weekly,
        current: current,
      );
    }

    return _resolveDaily(
      data: data,
      current: current,
    );
  }

  static BusinessHoursStatus _resolveWeekly({
    required Map<String, dynamic> data,
    required Map<String, dynamic> weekly,
    required DateTime current,
  }) {
    final todayIndex = current.weekday - 1;
    final yesterdayIndex = (todayIndex + 6) % 7;

    final today = _daySchedule(
      weekly[_dayKeys[todayIndex]],
      data: data,
    );

    final yesterday = _daySchedule(
      weekly[_dayKeys[yesterdayIndex]],
      data: data,
    );

    final nowMinutes = current.hour * 60 + current.minute;

    // إذا كان دوام أمس يمتد بعد منتصف الليل، مثل 10:00 → 03:00.
    if (!yesterday.closed &&
        yesterday.open != null &&
        yesterday.close != null &&
        yesterday.close! <= yesterday.open! &&
        nowMinutes < yesterday.close!) {
      final remaining = yesterday.close! - nowMinutes;

      return BusinessHoursStatus(
        code: remaining <= 60 ? 'closing_soon' : 'open',
        label: remaining <= 60 ? 'يغلق قريبًا' : 'مفتوح',
        isAcceptingOrders: true,
        minutesUntilChange: remaining,
      );
    }

    if (!today.closed && today.open != null && today.close != null) {
      final open = today.open!;
      final close = today.close!;
      final crossesMidnight = close <= open;

      if (!crossesMidnight) {
        if (nowMinutes >= open && nowMinutes < close) {
          final remaining = close - nowMinutes;

          return BusinessHoursStatus(
            code: remaining <= 60 ? 'closing_soon' : 'open',
            label: remaining <= 60 ? 'يغلق قريبًا' : 'مفتوح',
            isAcceptingOrders: true,
            minutesUntilChange: remaining,
          );
        }
      } else if (nowMinutes >= open) {
        final remaining = (24 * 60 - nowMinutes) + close;

        return BusinessHoursStatus(
          code: remaining <= 60 ? 'closing_soon' : 'open',
          label: remaining <= 60 ? 'يغلق قريبًا' : 'مفتوح',
          isAcceptingOrders: true,
          minutesUntilChange: remaining,
        );
      }

      if (nowMinutes < open) {
        final untilOpen = open - nowMinutes;

        if (untilOpen <= 60) {
          return BusinessHoursStatus(
            code: 'opening_soon',
            label: 'يفتح قريبًا',
            isAcceptingOrders: false,
            minutesUntilChange: untilOpen,
          );
        }
      }
    }

    final nextOpening = _minutesUntilNextOpening(
      weekly: weekly,
      data: data,
      current: current,
    );

    if (nextOpening != null && nextOpening <= 60) {
      return BusinessHoursStatus(
        code: 'opening_soon',
        label: 'يفتح قريبًا',
        isAcceptingOrders: false,
        minutesUntilChange: nextOpening,
      );
    }

    return BusinessHoursStatus(
      code: 'closed',
      label: 'مغلق',
      isAcceptingOrders: false,
      minutesUntilChange: nextOpening,
    );
  }

  static BusinessHoursStatus _resolveDaily({
    required Map<String, dynamic> data,
    required DateTime current,
  }) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';

    final openingTime =
        data['openingTime']?.toString().trim().isNotEmpty == true
            ? data['openingTime'].toString().trim()
            : type == 'market'
                ? '10:00'
                : '08:00';

    final closingTime =
        data['closingTime']?.toString().trim().isNotEmpty == true
            ? data['closingTime'].toString().trim()
            : type == 'market'
                ? '03:00'
                : '23:00';

    final openMinutes = _parseTime(openingTime);
    final closeMinutes = _parseTime(closingTime);

    if (openMinutes == null || closeMinutes == null) {
      return const BusinessHoursStatus(
        code: 'open',
        label: 'مفتوح',
        isAcceptingOrders: true,
        minutesUntilChange: null,
      );
    }

    final nowMinutes = current.hour * 60 + current.minute;
    final crossesMidnight = closeMinutes <= openMinutes;

    if (!crossesMidnight) {
      if (nowMinutes >= openMinutes && nowMinutes < closeMinutes) {
        final remaining = closeMinutes - nowMinutes;

        return BusinessHoursStatus(
          code: remaining <= 60 ? 'closing_soon' : 'open',
          label: remaining <= 60 ? 'يغلق قريبًا' : 'مفتوح',
          isAcceptingOrders: true,
          minutesUntilChange: remaining,
        );
      }

      final untilOpen = nowMinutes < openMinutes
          ? openMinutes - nowMinutes
          : (24 * 60 - nowMinutes) + openMinutes;

      return BusinessHoursStatus(
        code: untilOpen <= 60 ? 'opening_soon' : 'closed',
        label: untilOpen <= 60 ? 'يفتح قريبًا' : 'مغلق',
        isAcceptingOrders: false,
        minutesUntilChange: untilOpen,
      );
    }

    final isOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes;

    if (isOpen) {
      final remaining = nowMinutes >= openMinutes
          ? (24 * 60 - nowMinutes) + closeMinutes
          : closeMinutes - nowMinutes;

      return BusinessHoursStatus(
        code: remaining <= 60 ? 'closing_soon' : 'open',
        label: remaining <= 60 ? 'يغلق قريبًا' : 'مفتوح',
        isAcceptingOrders: true,
        minutesUntilChange: remaining,
      );
    }

    final untilOpen = openMinutes - nowMinutes;

    return BusinessHoursStatus(
      code: untilOpen <= 60 ? 'opening_soon' : 'closed',
      label: untilOpen <= 60 ? 'يفتح قريبًا' : 'مغلق',
      isAcceptingOrders: false,
      minutesUntilChange: untilOpen,
    );
  }

  static Map<String, dynamic>? _weeklyHours(
    Map<String, dynamic> data,
  ) {
    final value = data['weeklyHours'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static _DaySchedule _daySchedule(
    dynamic value, {
    required Map<String, dynamic> data,
  }) {
    if (value is! Map) {
      return const _DaySchedule(
        closed: true,
        open: null,
        close: null,
      );
    }

    final day = Map<String, dynamic>.from(value);

    if (day['closed'] == true) {
      return const _DaySchedule(
        closed: true,
        open: null,
        close: null,
      );
    }

    return _DaySchedule(
      closed: false,
      open: _parseTime(day['open']?.toString() ?? ''),
      close: _parseTime(day['close']?.toString() ?? ''),
    );
  }

  static int? _minutesUntilNextOpening({
    required Map<String, dynamic> weekly,
    required Map<String, dynamic> data,
    required DateTime current,
  }) {
    final nowMinutes = current.hour * 60 + current.minute;
    final todayIndex = current.weekday - 1;

    for (var offset = 0; offset <= 7; offset++) {
      final dayIndex = (todayIndex + offset) % 7;

      final schedule = _daySchedule(
        weekly[_dayKeys[dayIndex]],
        data: data,
      );

      if (schedule.closed || schedule.open == null) {
        continue;
      }

      if (offset == 0) {
        if (schedule.open! > nowMinutes) {
          return schedule.open! - nowMinutes;
        }
        continue;
      }

      return ((24 * 60 - nowMinutes) +
          ((offset - 1) * 24 * 60) +
          schedule.open!);
    }

    return null;
  }

  static int? _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }
}

class _DaySchedule {
  const _DaySchedule({
    required this.closed,
    required this.open,
    required this.close,
  });

  final bool closed;
  final int? open;
  final int? close;
}
