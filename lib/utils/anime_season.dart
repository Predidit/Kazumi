/// This class asks for DateTime to get a string to indicate seasonal anime
class AnimeSeason {
  late DateTime _date;
  final _seasons = ['冬季', '春季', '夏季', '秋季'];

  AnimeSeason(DateTime date) {
    _date = date;
  }

  List<int> _getYearAndSeason(DateTime dt) {
    int year = dt.year;
    int month = dt.month;

    int season;
    if ((month == 1) || (month == 2) || (month == 3)) {
      season = 0;
    } else if ((month == 4) || (month == 5) || (month == 6)) {
      season = 1;
    } else if ((month == 7) || (month == 8) || (month == 9)) {
      season = 2;
    } else {
      season = 3;
    }

    return [year, season];
  }

  // Convert the DateTime to a List containing two strings (the start of the season -1 and the end of the season -1 ) eg: 2024-09-23 -> ['2024-06-01', '2024-09-01']
  // why -1? because the air date is the launch date of the anime, it is usually a few days before the start of the season
  List<String> toSeasonStartAndEnd() {
    var yas = _getYearAndSeason(_date);
    int year = yas[0];
    int season = yas[1];

    var end = DateTime(year, (season + 1) * 3, 1);

    int startMonth = season * 3;
    if (startMonth == 0) {
      startMonth = 12;
      year--;
    }

    var start = DateTime(year, startMonth, 1);
    return [start.toString(), end.toString()];
  }

  @override
  String toString() {
    var yas = _getYearAndSeason(_date);

    return '${yas[0]}年${_seasons[yas[1]]}新番';
  }
}
