import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Opt-in frame sampling for distinguishing scroll offsets, transforms and the
/// shader-based Android stretch effect. Enable with APP_REFRESH_TRACE=true.
class ScrollDebugProbe extends StatefulWidget {
  static const enabled = bool.fromEnvironment('APP_REFRESH_TRACE');

  final ScrollController controller;
  final GlobalKey contentKey;
  final String label;
  final Widget child;

  const ScrollDebugProbe({
    super.key,
    required this.controller,
    required this.contentKey,
    required this.label,
    required this.child,
  });

  @override
  State<ScrollDebugProbe> createState() => _ScrollDebugProbeState();
}

class _ScrollDebugProbeState extends State<ScrollDebugProbe>
    with SingleTickerProviderStateMixin {
  final _viewportKey = GlobalKey();
  Ticker? _ticker;
  String? _previous;

  @override
  void initState() {
    super.initState();
    if (ScrollDebugProbe.enabled) {
      _ticker = createTicker((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sample());
      })..start();
      _trace('sampling started');
    }
  }

  void _sample() {
    if (!mounted) return;
    if (widget.controller.positions.length != 1) {
      _trace(
        'waiting for one ScrollPosition: ${widget.controller.positions.length}',
      );
      return;
    }
    final contentContext = widget.contentKey.currentContext;
    final content = contentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (content is! RenderBox || viewport is! RenderBox) {
      _trace('waiting for RenderBoxes: content=$content viewport=$viewport');
      return;
    }
    if (!content.hasSize || !viewport.hasSize) {
      _trace('waiting for layout');
      return;
    }

    final position = widget.controller.position;
    final screenTransform = content.getTransformTo(null);
    final relativeTransform = content.getTransformTo(viewport);
    final stretches = <double>[];
    contentContext!.visitAncestorElements((element) {
      if (element.widget case StretchEffect(:final stretchStrength)) {
        stretches.add(stretchStrength);
      }
      return true;
    });
    final sample =
        'pixels=${position.pixels.toStringAsFixed(3)} '
        'min=${position.minScrollExtent} max=${position.maxScrollExtent} '
        'viewport=${_rectCoordinates(MatrixUtils.transformRect(viewport.getTransformTo(null), Offset.zero & viewport.size))} '
        'content=${_rectCoordinates(MatrixUtils.transformRect(screenTransform, Offset.zero & content.size))} '
        'relative=${relativeTransform.storage.toList()} '
        'screen=${screenTransform.storage.toList()} stretch=$stretches';
    _trace(sample);
  }

  void _trace(String sample) {
    if (sample == _previous) return;
    _previous = sample;
    debugPrint('[refresh-geometry:${widget.label}] $sample');
  }

  // Rect.toString() is stripped to "Instance of 'Rect'" in release builds.
  List<double> _rectCoordinates(Rect rect) => [
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
  ];

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollDebugProbe.enabled
      ? KeyedSubtree(key: _viewportKey, child: widget.child)
      : widget.child;
}
