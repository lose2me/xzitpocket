import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

/// 单列滚轮的一个可选项：[label] 是给用户看的完整路径，[value] 是最终叶子节点。
class WheelChoice<T> {
  final String label;
  final T value;

  const WheelChoice({required this.label, required this.value});
}

/// 单列滚轮选择器：把所有层级扁平化成一条条完整路径，用户只需在一个滚轮里
/// 滚动到目标地点/项目即可，不需要一级一级逐层点选。
class SingleWheelSheet<T> extends StatefulWidget {
  final String title;
  final List<WheelChoice<T>> choices;

  const SingleWheelSheet({
    super.key,
    required this.title,
    required this.choices,
  });

  @override
  State<SingleWheelSheet<T>> createState() => _SingleWheelSheetState<T>();
}

class _SingleWheelSheetState<T> extends State<SingleWheelSheet<T>> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.typography.tileTitle),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: FPicker(
                control: FPickerControl.lifted(
                  indexes: [_index],
                  onChange: (indexes) => setState(() => _index = indexes.first),
                ),
                children: [
                  FPickerWheel(
                    semanticsLabel: widget.title,
                    children: [
                      for (final choice in widget.choices) Text(choice.label),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: () => Navigator.pop(context, widget.choices[_index]),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
