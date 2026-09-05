import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

class PaletteCard extends StatelessWidget {
  final Color color;
  final bool selected;

  const PaletteCard({
    super.key,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = M3EColorScheme.generate(
      seedColor: color,
      brightness: Theme.of(context).brightness,
    );
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        children: [
          Card(
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              color: scheme.tertiary,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: scheme.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Center(
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: scheme.onPrimary,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
