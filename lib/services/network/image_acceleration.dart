enum ImageAcceleration {
  direct,
  ech,
  mirror;

  static ImageAcceleration fromSetting(String value) =>
      values.firstWhere((mode) => mode.name == value, orElse: () => ech);
}
