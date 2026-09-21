enum CollectLayout {
  list('列表'),
  cards('卡片');

  const CollectLayout(this.label);

  final String label;

  static CollectLayout fromValue(String value) =>
      value == cards.name ? cards : list;
}
