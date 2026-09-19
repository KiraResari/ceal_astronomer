class NoveanDate {
  const NoveanDate({
    required this.year,
    required this.isAN,
    required this.month,
    required this.day,
  });

  final int year;
  final bool isAN;
  final int month;
  final int day;

  static const List<String> monthNames = [
    'Tygfeeito',
    'Helfeeita',
    'Linnfeeita',
    'Fetafeeita',
    'Kitifeeito',
    'Nefeeita',
    'Kleefeeito',
    'Niafeeito',
    'Kellfeeito',
    'Jelfeeito',
    'Cinfeeita',
    'Falcefeeita',
    'Nalfeeita',
  ];

  static const List<String> dayNames = [
    'Eylycnyto',
    'Eylynyta',
    'Eyjelnyta',
    'Eyreynyta',
    'Eyeknyto',
    'Eyaenyta',
    'Eykenyto',
    'Eyhaenyto',
    'Eynanyto',
    'Eyarnyto',
    'Eykynyta',
    'Eyjylnyta',
    'Kelycnyto',
    'Kelynyta',
    'Kejelnyta',
    'Kereynyta',
    'Keknyto',
    'Keyaenyta',
    'Kekenyto',
    'Kehaenyto',
    'Kenanyto',
    'Kearnyto',
    'Kekynyta',
    'Kejylnyta',
  ];

  String get era => isAN ? 'AN' : 'BN';

  String get monthName => monthNames[month - 1];

  String get dayName {
    if (month == 13 && day == 13) {
      return 'Iylnyta';
    }

    return dayNames[day - 1];
  }

  String get formatted {
    return '$dayName $monthName ($day-$month) $era $year';
  }

  Map<String, dynamic> toJson() => {
    'year': year,
    'era': era,
    'month': month,
    'day': day,
  };

  factory NoveanDate.fromJson(Map<String, dynamic> json) {
    final era = (json['era'] as String?) ?? 'AN';

    return NoveanDate(
      year: (json['year'] as num).toInt(),
      isAN: era.toUpperCase() != 'BN',
      month: (json['month'] as num).toInt(),
      day: (json['day'] as num).toInt(),
    );
  }

  @override
  String toString() => formatted;
}

class NoveanCalendar {
  static bool isLeapYear(int year) {
    if (year <= 0) {
      throw ArgumentError('Novean year numbers must be positive.');
    }

    if (year % 1800 == 0) {
      return false;
    }

    if (year % 900 == 0) {
      return true;
    }

    if (year % 300 == 0) {
      return false;
    }

    return year % 6 == 0;
  }

  static int daysInYear(int year) {
    return isLeapYear(year) ? 301 : 300;
  }

  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 13) {
      throw ArgumentError('Month must be from 1 to 13.');
    }

    if (month <= 12) {
      return 24;
    }

    return isLeapYear(year) ? 13 : 12;
  }

  static bool isValidDate(NoveanDate date) {
    if (date.year < 1) {
      return false;
    }

    if (date.month < 1 || date.month > 13) {
      return false;
    }

    if (date.day < 1) {
      return false;
    }

    return date.day <= daysInMonth(date.year, date.month);
  }

  static int _leapYearsThrough(int year) {
    if (year <= 0) {
      return 0;
    }

    return year ~/ 6 -
        year ~/ 300 +
        year ~/ 900 -
        year ~/ 1800;
  }

  static int _daysThroughYear(int year) {
    if (year <= 0) {
      return 0;
    }

    return year * 300 + _leapYearsThrough(year);
  }

  static int toSerialDay(NoveanDate date) {
    if (!isValidDate(date)) {
      throw ArgumentError('Invalid Novean date: ${date.formatted}');
    }

    int startOfYear;

    if (date.isAN) {
      startOfYear = _daysThroughYear(date.year - 1);
    } else {
      startOfYear = -_daysThroughYear(date.year);
    }

    var dayOfYear = 0;

    for (var month = 1; month < date.month; month++) {
      dayOfYear += daysInMonth(date.year, month);
    }

    dayOfYear += date.day - 1;

    return startOfYear + dayOfYear;
  }

  static NoveanDate fromSerialDay(int serialDay) {
    if (serialDay >= 0) {
      return _fromPositiveSerialDay(serialDay);
    }

    return _fromNegativeSerialDay(serialDay);
  }

  static NoveanDate _fromPositiveSerialDay(int serialDay) {
    var year = serialDay ~/ 300 + 1;

    while (_daysThroughYear(year - 1) > serialDay) {
      year--;
    }

    while (_daysThroughYear(year) <= serialDay) {
      year++;
    }

    final startOfYear = _daysThroughYear(year - 1);
    final dayOfYear = serialDay - startOfYear;

    return _dateFromDayOfYear(
      year: year,
      isAN: true,
      dayOfYear: dayOfYear,
    );
  }

  static NoveanDate _fromNegativeSerialDay(int serialDay) {
    final daysBeforeAN1 = -serialDay;

    var year = (daysBeforeAN1 - 1) ~/ 300 + 1;

    while (_daysThroughYear(year) < daysBeforeAN1) {
      year++;
    }

    while (year > 1 &&
        _daysThroughYear(year - 1) >= daysBeforeAN1) {
      year--;
    }

    final startOfYear = -_daysThroughYear(year);
    final dayOfYear = serialDay - startOfYear;

    return _dateFromDayOfYear(
      year: year,
      isAN: false,
      dayOfYear: dayOfYear,
    );
  }

  static NoveanDate _dateFromDayOfYear({
    required int year,
    required bool isAN,
    required int dayOfYear,
  }) {
    var remaining = dayOfYear;
    var month = 1;

    while (true) {
      final length = daysInMonth(year, month);

      if (remaining < length) {
        break;
      }

      remaining -= length;
      month++;
    }

    return NoveanDate(
      year: year,
      isAN: isAN,
      month: month,
      day: remaining + 1,
    );
  }

  static NoveanDate addDays(NoveanDate date, int days) {
    return fromSerialDay(toSerialDay(date) + days);
  }
}