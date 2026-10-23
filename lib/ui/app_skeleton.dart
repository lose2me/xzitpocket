import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A single placeholder block used while remote content is not available yet.
class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.theme.colors.muted,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Pulses a group of [AppSkeletonBox]es as one unit, so a page only needs a
/// single animation controller. Screen readers hear [label] once instead of
/// the individual empty blocks.
class AppSkeleton extends StatefulWidget {
  final Widget child;
  final String label;

  const AppSkeleton({super.key, required this.child, this.label = '正在加载'});

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.42,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the platform "remove animations" accessibility setting.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      container: true,
      child: ExcludeSemantics(
        child: FadeTransition(opacity: _opacity, child: widget.child),
      ),
    );
  }
}
