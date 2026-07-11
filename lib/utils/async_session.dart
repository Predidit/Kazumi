/// Owns the currently active asynchronous operation in a replaceable sequence.
///
/// Starting a new session invalidates the previous one. [cancel] invalidates
/// the current session while keeping the owner reusable, and [close] makes the
/// owner permanently reject new work.
final class AsyncSessionOwner {
  int _version = 0;
  bool _closed = false;

  bool get isClosed => _closed;

  AsyncSession begin() {
    if (_closed) {
      throw StateError('Cannot begin a session after the owner is closed.');
    }
    return AsyncSession._(this, ++_version);
  }

  void cancel() {
    if (!_closed) {
      _version++;
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _version++;
  }

  bool _owns(AsyncSession session) {
    return !_closed &&
        identical(session._owner, this) &&
        session._version == _version;
  }
}

final class AsyncSession {
  const AsyncSession._(this._owner, this._version);

  final AsyncSessionOwner _owner;
  final int _version;

  bool get isActive => _owner._owns(this);

  bool get isStale => !isActive;
}
