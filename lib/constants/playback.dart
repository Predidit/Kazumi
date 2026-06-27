/// 可选播放倍速
const List<double> defaultPlaySpeedList = [
  0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0,
];

/// 可选默认视频比例
const Map<int, String> aspectRatioTypeMap = {
  1: "自动",
  2: "裁切填充",
  3: "拉伸填充",
};

/// 可选播放器日志等级
/// LogLevel 0: 错误 1: 警告 2: 简略 3: 详细 4: 调试（隐藏） 5: 全部（隐藏）
const Map<int, String> playerLogLevelMap = {
  0: "错误",
  1: "警告",
  2: "简略",
  3: "详细",
  // 以下两个级别被MPV官方支持，但是输出内容过于冗长，暂时隐藏
  // 4: "调试",
  // 5: "全部",
};
