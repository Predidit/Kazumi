
import 'package:kazumi/modules/collect/collect_type.dart';

/// Bangumi 远程收藏信息（包含最后更新时间）
class BangumiRemoteCollection {
  DateTime updatedAt;     // 最后更新时间，秒级
  int bangumiId;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  int type;
  String? date;    // 上映日期 "2025-04-12"
  String name;
  String nameCn;
  String shortSummary;
  double score;    // 平均评分
  int eps;    // 总集数
  int rank;   // 排名

  BangumiRemoteCollection(
      this.bangumiId,
      this.date,
      this.updatedAt,
      this.type,
      this.name,
      this.nameCn,
      this.shortSummary,
      this.score,
      this.eps,
      this.rank);

  int getUpdateAtToInt() {
    return updatedAt.millisecondsSinceEpoch ~/ 1000;
  }

  factory BangumiRemoteCollection.fromJson(Map json) {
    final subject = json['subject'];
    return BangumiRemoteCollection(
      subject['id'],
      subject['date'],
      DateTime.parse(json['updated_at']),
      CollectType.fromBangumi(json['type']).value,
      subject['name'],
      subject['name_cn'],
      subject['short_summary'],
      (subject['score'] as num).toDouble(),
      subject['eps'],
      subject['rank']
    );
  }
}

// final EXANPLE = {
//   "updated_at": "2026-04-10T22:01:53+08:00",
//   "comment": null,
//   "tags": [],
//   "subject": {
//     "date": "2025-04-12",
//     "images": {
//       "small": "https://lain.bgm.tv/r/200/pic/cover/l/d3/5d/531159_BayD9.jpg",
//       "grid": "https://lain.bgm.tv/r/100/pic/cover/l/d3/5d/531159_BayD9.jpg",
//       "large": "https://lain.bgm.tv/pic/cover/l/d3/5d/531159_BayD9.jpg",
//       "medium": "https://lain.bgm.tv/r/800/pic/cover/l/d3/5d/531159_BayD9.jpg",
//       "common": "https://lain.bgm.tv/r/400/pic/cover/l/d3/5d/531159_BayD9.jpg"
//     },
//     "name": "日々は過ぎれど飯うまし",
//     "name_cn": "时光流逝，饭菜依旧美味",
//     "short_summary": "可爱×美味=最强美食\r\n五名刚刚成为大学生的女孩们共同演绎的日常故事。\r\n热爱美食，想和大家一起尽情玩耍，学习也要稍加努力，如此这般，尽情享受大学生活吧！",
//     "tags": [
//       {
//         "name": "原创",
//         "count": 3161,
//         "total_cont": 0
//       },
//       {
//         "name": "美食",
//         "count": 2981,
//         "total_cont": 0
//       },
//       {
//         "name": "P.A.WORKS",
//         "count": 2969,
//         "total_cont": 0
//       },
//       {
//         "name": "日常",
//         "count": 2961,
//         "total_cont": 0
//       },
//       {
//         "name": "2025年4月",
//         "count": 2046,
//         "total_cont": 0
//       },
//       {
//         "name": "TV",
//         "count": 1726,
//         "total_cont": 0
//       },
//       {
//         "name": "轻百合",
//         "count": 1661,
//         "total_cont": 0
//       },
//       {
//         "name": "日本",
//         "count": 1012,
//         "total_cont": 0
//       },
//       {
//         "name": "2025",
//         "count": 1003,
//         "total_cont": 0
//       },
//       {
//         "name": "轻百",
//         "count": 840,
//         "total_cont": 0
//       }
//     ],
//     "score": 7.7,
//     "type": 2,
//     "id": 531159,
//     "eps": 12,
//     "volumes": 0,
//     "collection_total": 26659,
//     "rank": 577
//   },
//   "subject_id": 531159,
//   "vol_status": 0,
//   "ep_status": 0,
//   "subject_type": 2,
//   "type": 3,
//   "rate": 0,
//   "private": false
// };