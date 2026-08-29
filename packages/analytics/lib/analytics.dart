library;

abstract interface class Analytics {
  void track(String event, [Map<String, Object?> parameters = const {}]);
}

class DebugAnalytics implements Analytics {
  const DebugAnalytics({this.onEvent});
  final void Function(String event, Map<String, Object?> parameters)? onEvent;
  @override
  void track(String event, [Map<String, Object?> parameters = const {}]) =>
      onEvent?.call(event, parameters);
}
