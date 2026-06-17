// 计算两个字符串的编辑距离, 曾用于弹幕标题匹配
// 由于 DanDanPlay 现在直接提供基于 bgmBangumiID 的弹幕反查，此方法已不再使用

import 'dart:math';

int levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;

  List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(s2.length + 1, 0);

  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;

    for (int j = 0; j < s2.length; j++) {
      int cost = (s1[i] == s2[j]) ? 0 : 1;
      v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
    }

    for (int j = 0; j < v0.length; j++) {
      v0[j] = v1[j];
    }
  }

  return v1[s2.length];
}

// 计算相似度百分比
double calculateSimilarity(String s1, String s2) {
  int maxLength = max(s1.length, s2.length);
  if (maxLength == 0) return 1.0;
  if (s1 == s2) return 1.0;
  return (1.0 - levenshteinDistance(s1, s2) / maxLength);
}
