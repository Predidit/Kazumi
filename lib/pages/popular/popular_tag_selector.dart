import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:kazumi/utils/constants.dart';

/// Keeps one tag selected and lets Back close the menu before leaving the page.
class PopularTagSelector extends StatefulWidget {
  const PopularTagSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.textStyle,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle? textStyle;

  @override
  State<PopularTagSelector> createState() => _PopularTagSelectorState();
}

class _PopularTagSelectorState extends State<PopularTagSelector> {
  final _controller = M3EDropdownController<String>();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMenuChanged);
  }

  void _onMenuChanged() {
    if (_isOpen != _controller.isOpen) {
      setState(() => _isOpen = _controller.isOpen);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onMenuChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.closeDropdown();
      },
      child: M3EDropdownMenu<String>(
        controller: _controller,
        singleSelect: true,
        showChipAnimation: false,
        fieldStyle: M3EDropdownFieldStyle(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          selectedTextStyle: widget.textStyle,
        ),
        items: [
          for (final tag in ['', ...defaultAnimeTags])
            M3EDropdownItem(
              label: tag.isEmpty ? '热门番组' : tag,
              value: tag,
              selected: tag == widget.value,
            ),
        ],
        onSelectionChanged: (items) {
          // M3E single-select can toggle off the current item; a filter cannot.
          if (items.isEmpty) {
            _controller.selectWhere((item) => item.value == widget.value);
          } else if (items.single.value != widget.value) {
            widget.onChanged(items.single.value);
          }
        },
      ),
    );
  }
}
