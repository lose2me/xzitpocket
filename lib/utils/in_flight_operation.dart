final class InFlightOperation<T> {
  Future<T>? _current;

  Future<T> run(Future<T> Function() operation) {
    final active = _current;
    if (active != null) return active;

    late final Future<T> future;
    future = operation().whenComplete(() {
      if (identical(_current, future)) _current = null;
    });
    _current = future;
    return future;
  }

  void invalidate() => _current = null;
}
