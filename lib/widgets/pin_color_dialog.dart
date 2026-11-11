import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_theme.dart';

class PinColorDialog extends StatefulWidget {
  final Color initialColor;

  const PinColorDialog({super.key, required this.initialColor});

  @override
  State<PinColorDialog> createState() => _PinColorDialogState();
}

class _PinColorDialogState extends State<PinColorDialog> {
  late Color _selectedColor;
  late Color _customColor;
  late final TextEditingController _hexController;
  final ScrollController _paletteScrollController = ScrollController();
  bool _customMode = false;
  bool _invalidHex = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _customColor = widget.initialColor;
    _hexController = TextEditingController(text: _hexText(_customColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    _paletteScrollController.dispose();
    super.dispose();
  }

  String _hexText(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _updateCustomColor(Color color, {bool updateText = true}) {
    setState(() {
      _selectedColor = color;
      _customColor = color;
      _customMode = true;
      _invalidHex = false;
    });
    if (updateText) {
      final text = _hexText(color);
      _hexController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onHexChanged(String text) {
    final digits = text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(digits)) {
      setState(() => _invalidHex = true);
      return;
    }
    _updateCustomColor(
      Color(0xFF000000 | int.parse(digits, radix: 16)),
      updateText: false,
    );
  }

  Widget _buildColorChoice({
    required Color color,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
    bool custom = false,
  }) {
    final checkColor = custom || color.computeLuminance() <= 0.5
        ? Colors.white
        : Colors.black;
    final icon = selected ? Icons.check : (custom ? Icons.add : null);
    return IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: onPressed,
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: custom ? null : color,
          gradient: custom
              ? const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                )
              : null,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: icon == null
            ? null
            : Icon(
                icon,
                color: checkColor,
                size: 18,
                shadows: custom
                    ? const [Shadow(color: Colors.black, blurRadius: 2)]
                    : null,
              ),
      ),
    );
  }

  Widget _buildChannelSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(value.round().toString()),
        ],
      ),
      Slider(
        value: value,
        min: 0,
        max: 255,
        divisions: 255,
        label: value.round().toString(),
        activeColor: color,
        onChanged: onChanged,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presets = <Color, String>{
      MapPalette.pinLightRed: l10n.map_pinColorLightRed,
      Colors.orange: l10n.map_pinColorOrange,
      MapPalette.pinRichRed: l10n.map_pinColorRichRed,
      Colors.yellow: l10n.map_pinColorYellow,
      Colors.lime: l10n.map_pinColorLime,
      Colors.green: l10n.map_pinColorGreen,
      Colors.teal: l10n.map_pinColorTeal,
      Colors.cyan: l10n.map_pinColorCyan,
      Colors.blue: l10n.map_pinColorBlue,
      Colors.indigo: l10n.map_pinColorIndigo,
      Colors.purple: l10n.map_pinColorPurple,
      Colors.pink: l10n.map_pinColorPink,
      Colors.brown: l10n.map_pinColorBrown,
      Colors.grey: l10n.map_pinColorGray,
      Colors.black: l10n.map_pinColorBlack,
    };
    final customSelected = _customMode || !presets.containsKey(_selectedColor);

    return AlertDialog(
      title: Text(l10n.map_pinColor),
      content: SizedBox(
        width: 416,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 384
                      ? 384.0
                      : constraints.maxWidth;
                  return SizedBox(
                    height: width / 4 + 12,
                    child: Scrollbar(
                      controller: _paletteScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _paletteScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: width,
                          height: width / 4,
                          child: GridView.count(
                            crossAxisCount: 8,
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            children: [
                              for (final preset in presets.entries)
                                _buildColorChoice(
                                  color: preset.key,
                                  label: preset.value,
                                  selected:
                                      !customSelected &&
                                      _selectedColor == preset.key,
                                  onPressed: () {
                                    setState(() {
                                      _selectedColor = preset.key;
                                      _customMode = false;
                                      _invalidHex = false;
                                    });
                                  },
                                ),
                              _buildColorChoice(
                                color: _customColor,
                                label: l10n.map_pinColorCustom,
                                selected: customSelected,
                                custom: true,
                                onPressed: () =>
                                    _updateCustomColor(_customColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (customSelected) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: l10n.map_pinColorHex,
                          errorText: _invalidHex
                              ? l10n.map_pinColorInvalidHex
                              : null,
                          errorMaxLines: 3,
                        ),
                        onChanged: _onHexChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildChannelSlider(
                  l10n.map_pinColorChannelRed,
                  (_selectedColor.r * 255).roundToDouble(),
                  Colors.red,
                  (value) => _updateCustomColor(
                    _selectedColor.withValues(red: value / 255),
                  ),
                ),
                _buildChannelSlider(
                  l10n.map_pinColorGreen,
                  (_selectedColor.g * 255).roundToDouble(),
                  Colors.green,
                  (value) => _updateCustomColor(
                    _selectedColor.withValues(green: value / 255),
                  ),
                ),
                _buildChannelSlider(
                  l10n.map_pinColorBlue,
                  (_selectedColor.b * 255).roundToDouble(),
                  Colors.blue,
                  (value) => _updateCustomColor(
                    _selectedColor.withValues(blue: value / 255),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _invalidHex
              ? null
              : () => Navigator.pop(context, _selectedColor),
          child: Text(l10n.common_apply),
        ),
      ],
    );
  }
}
