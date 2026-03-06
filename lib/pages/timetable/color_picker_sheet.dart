import 'package:flutter/material.dart';

class ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  const ColorPickerSheet({super.key, required this.initialColor});

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 20),
            _buildSlider(
              label: '色相',
              value: _hsv.hue,
              max: 360,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _buildSlider(
              label: '饱和度',
              value: _hsv.saturation,
              max: 1,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _buildSlider(
              label: '亮度',
              value: _hsv.value,
              max: 1,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, color),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: max,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
