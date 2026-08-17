import 'package:flutter/material.dart';
import 'package:group_button/group_button.dart';
import 'package:talker_flutter/src/controller/controller.dart';
import 'package:talker_flutter/talker_flutter.dart';

class TalkerViewAppBar extends StatefulWidget {
  const TalkerViewAppBar({
    Key? key,
    required this.title,
    required this.leading,
    required this.talker,
    required this.talkerTheme,
    required this.controller,
    required this.keys,
    required this.uniqKeys,
    required this.onMonitorTap,
    required this.onSettingsTap,
    required this.onActionsTap,
    required this.onToggleKey,
  }) : super(key: key);

  final String? title;
  final Widget? leading;

  final Talker talker;
  final TalkerScreenTheme talkerTheme;

  final TalkerViewController controller;

  final List<String?> keys;
  final List<String?> uniqKeys;

  final VoidCallback onMonitorTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onActionsTap;

  final Function(String key, bool selected) onToggleKey;

  @override
  State<TalkerViewAppBar> createState() => _TalkerViewAppBarState();
}

class _TalkerViewAppBarState extends State<TalkerViewAppBar>
    with WidgetsBindingObserver {
  final GlobalKey _groupButtonKey = GlobalKey();
  final GlobalKey _searchTextFieldKey = GlobalKey();
  final _bcontroller = GroupButtonController();

  double? _spaceBarHeight;
  bool _heightCalculationScheduled = false;

  final double _defaultSpaceBarHeight = 50;

  final double _defaultToolbarHeight = 60;

  static const double _padding = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleHeightCalculation();
    final indexes = widget.talker.filter.enabledKeys
        .map((e) => widget.keys.indexOf(e))
        .where((index) => index >= 0)
        .toList();
    _bcontroller.selectIndexes(indexes);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scheduleHeightCalculation();
  }

  @override
  void didUpdateWidget(covariant TalkerViewAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHeightCalculation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bcontroller.dispose();
    super.dispose();
  }

  void _scheduleHeightCalculation() {
    if (_heightCalculationScheduled) return;
    _heightCalculationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightCalculationScheduled = false;
      if (mounted) _calculateHeight();
    });
  }

  void _calculateHeight() {
    final groupButtonBox =
        _groupButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final searchFieldBox =
        _searchTextFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (groupButtonBox == null || searchFieldBox == null) return;

    // Measure the fixed-height children rather than their parent. The parent is
    // constrained by expandedHeight, so feeding its size back into the app bar
    // causes the height to grow on every frame and pushes the log list away.
    final height = _defaultToolbarHeight +
        groupButtonBox.size.height +
        searchFieldBox.size.height +
        _padding;
    if (_spaceBarHeight == null || (_spaceBarHeight! - height).abs() > 0.5) {
      setState(() => _spaceBarHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uniqKeys = widget.uniqKeys..removeWhere((e) => e == null);
    return SliverAppBar(
      backgroundColor: widget.talkerTheme.backgroundColor,
      elevation: 0,
      pinned: true,
      floating: true,
      expandedHeight: _spaceBarHeight ?? _defaultSpaceBarHeight,
      collapsedHeight: _defaultToolbarHeight,
      toolbarHeight: _defaultToolbarHeight,
      leading: widget.leading,
      iconTheme: IconThemeData(color: widget.talkerTheme.textColor),
      actions: [
        UnconstrainedBox(
          child: _MonitorButton(
            talker: widget.talker,
            onPressed: widget.onMonitorTap,
            talkerTheme: widget.talkerTheme,
          ),
        ),
        UnconstrainedBox(
          child: IconButton(
            onPressed: widget.onSettingsTap,
            icon: Icon(
              Icons.settings_rounded,
              color: widget.talkerTheme.textColor,
            ),
          ),
        ),
        UnconstrainedBox(
          child: IconButton(
            onPressed: widget.onActionsTap,
            icon: Icon(
              Icons.menu_rounded,
              color: widget.talkerTheme.textColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      title: widget.title != null
          ? Text(
              widget.title!,
              style: TextStyle(
                color: widget.talkerTheme.textColor,
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GroupButton(
                    key: _groupButtonKey,
                    controller: _bcontroller,
                    isRadio: false,
                    buttonBuilder: (selected, key, context) {
                      final count = widget.keys.where((e) => e == key).length;
                      final title = key != null
                          ? widget.talker.settings.getTitleByKey(key)
                          : '未定义';
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: widget.talkerTheme.textColor),
                          borderRadius: BorderRadius.circular(10),
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : widget.talkerTheme.cardColor,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.talkerTheme.textColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.talkerTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onSelected: (_, i, selected) => _onToggleKey(
                      uniqKeys[i],
                      selected,
                    ),
                    buttons: uniqKeys,
                  ),
                ),
                const SizedBox(height: _padding),
                _SearchTextField(
                  key: _searchTextFieldKey,
                  controller: widget.controller,
                  talkerTheme: widget.talkerTheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onToggleKey(String? key, bool selected) {
    if (key == null) return;
    widget.onToggleKey(key, selected);
  }
}

class _SearchTextField extends StatelessWidget {
  const _SearchTextField({
    super.key,
    required this.talkerTheme,
    required this.controller,
  });

  final TalkerScreenTheme talkerTheme;
  final TalkerViewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        style: theme.textTheme.bodyLarge!.copyWith(
          color: talkerTheme.textColor,
          fontSize: 14,
        ),
        onChanged: controller.updateFilterSearchQuery,
        decoration: InputDecoration(
          fillColor: talkerTheme.backgroundColor,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: talkerTheme.textColor),
            borderRadius: BorderRadius.circular(10),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: talkerTheme.textColor),
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: Icon(
            Icons.search,
            color: talkerTheme.textColor,
            size: 20,
          ),
          hintText: '搜索...',
          hintStyle: theme.textTheme.bodyLarge!.copyWith(
            color: talkerTheme.textColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MonitorButton extends StatelessWidget {
  const _MonitorButton({
    Key? key,
    required this.talker,
    required this.onPressed,
    required this.talkerTheme,
  }) : super(key: key);

  final Talker talker;
  final TalkerScreenTheme talkerTheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TalkerBuilder(
      talker: talker,
      builder: (context, data) {
        final haveErrors = data
            .where((e) => e is TalkerError || e is TalkerException)
            .isNotEmpty;
        return Stack(
          children: [
            Center(
              child: IconButton(
                onPressed: onPressed,
                icon: Icon(
                  Icons.monitor_heart_outlined,
                  color: talkerTheme.textColor,
                ),
              ),
            ),
            if (haveErrors)
              Positioned(
                right: 6,
                top: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  height: 7,
                  width: 7,
                ),
              ),
          ],
        );
      },
    );
  }
}
