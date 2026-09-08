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

  /// Waits for any active operation before starting a new one.
  ///
  /// Unlike [run], this guarantees that [operation] is not satisfied by a
  /// request that started before the caller asked for fresh data.
  Future<T> runAfterCurrent(Future<T> Function() operation) async {
    final active = _current;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // A failed active request must not prevent the fresh request.
      }
    }
    return run(operation);
  }

  void invalidate() => _current = null;
}
