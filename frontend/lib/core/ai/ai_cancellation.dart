import 'dart:async';

class AiCancelled implements Exception {
  const AiCancelled();
}

class AiCancelToken {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get cancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) throw const AiCancelled();
  }

  Future<T> wait<T>(Future<T> work) =>
      Future.any([work, cancelled.then<T>((_) => throw const AiCancelled())]);
}
