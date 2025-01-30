import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class PaletteCard extends StatefulWidget {
  final Color color;
  final bool selected;

  const PaletteCard({
    super.key,
    required this.color,
    required this.selected,
  });

  @override
  State<StatefulWidget> createState() => _PaletteCardState();
}

class _PaletteCardState extends State<PaletteCard> {
  @override
  Widget build(BuildContext context) {
    final Hct hct = Hct.fromInt(widget.color.value);
    final primary = Color(Hct.from(hct.hue, 20.0, 90.0).toInt());
    final tertiary = Color(Hct.from(hct.hue + 50, 20.0, 85.0).toInt());
    final primaryContainer = Color(Hct.from(hct.hue, 30.0, 50.0).toInt());
    final checkbox = Color(Hct.from(hct.hue, 30.0, 40.0).toInt());
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
                        color: primary,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              color: tertiary,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: primaryContainer,
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
          if (widget.selected)
            Center(
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: checkbox,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
