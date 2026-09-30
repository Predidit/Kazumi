// Persisted values match dandanplay's chConvert parameter.
enum DanmakuChConvert {
  none(0),
  simplified(1),
  traditional(2);

  const DanmakuChConvert(this.value);

  final int value;

  static DanmakuChConvert fromValue(int value) => switch (value) {
    1 => simplified,
    2 => traditional,
    _ => none,
  };
}
