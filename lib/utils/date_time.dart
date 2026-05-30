String formatTimestampToRelativeTime(int timeStamp) {
  final difference = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000));

  if (difference.inDays > 365) {
    return '${difference.inDays ~/ 365}y ago';
  } else if (difference.inDays > 30) {
    return '${difference.inDays ~/ 30}mo ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  }
  return 'Just now';
}

String dateFormat(int timeStamp, {String formatType = 'list'}) {
  final time = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  final distance = time - timeStamp;
  var currentYearStr = 'MM-DD hh:mm';
  var lastYearStr = 'YY-MM-DD hh:mm';
  if (formatType == 'detail') {
    currentYearStr = 'MM-DD hh:mm';
    lastYearStr = 'YY-MM-DD hh:mm';
    return _customTimestampString(
      timestamp: timeStamp,
      date: lastYearStr,
      toInt: false,
      formatType: formatType,
    );
  }
  if (distance <= 60) {
    return 'Just now';
  } else if (distance <= 3600) {
    return '${(distance / 60).floor()}m ago';
  } else if (distance <= 43200) {
    return '${(distance / 60 / 60).floor()}h ago';
  } else if (DateTime.fromMillisecondsSinceEpoch(time * 1000).year ==
      DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000).year) {
    return _customTimestampString(
      timestamp: timeStamp,
      date: currentYearStr,
      toInt: false,
      formatType: formatType,
    );
  }
  return _customTimestampString(
    timestamp: timeStamp,
    date: lastYearStr,
    toInt: false,
    formatType: formatType,
  );
}

String _customTimestampString({
  int? timestamp,
  String? date,
  bool toInt = true,
  String? formatType,
}) {
  timestamp ??= (DateTime.now().millisecondsSinceEpoch / 1000).round();
  final timeStr =
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toString();
  final dateArr = timeStr.split(' ')[0];
  final timeArr = timeStr.split(' ')[1];

  final yy = dateArr.split('-')[0];
  var mm = dateArr.split('-')[1];
  var dd = dateArr.split('-')[2];
  var hh = timeArr.split(':')[0];
  var minute = timeArr.split(':')[1];
  var ss = timeArr.split(':')[2].split('.')[0];

  if (toInt) {
    mm = int.parse(mm).toString();
    dd = int.parse(dd).toString();
    hh = int.parse(hh).toString();
    minute = int.parse(minute).toString();
  }

  if (date == null) {
    return timeStr;
  }

  final formatted = date
      .replaceAll('YY', yy)
      .replaceAll('MM', mm)
      .replaceAll('DD', dd)
      .replaceAll('hh', hh)
      .replaceAll('mm', minute)
      .replaceAll('ss', ss);
  if (int.parse(yy) == DateTime.now().year &&
      int.parse(mm) == DateTime.now().month &&
      int.parse(dd) == DateTime.now().day) {
    return 'Today';
  }
  return formatted;
}

int dateStringToWeekday(String dateString) {
  try {
    return DateTime.parse(dateString).weekday;
  } catch (_) {
    return 1;
  }
}

String formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return dateString;
  }
}
