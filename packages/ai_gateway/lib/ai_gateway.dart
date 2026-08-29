library;

abstract interface class AiService {
  Future<String> generateMemoryTitle({required String memoryId});
  Future<String> generateMemorySummary({required String memoryId});
  Future<String> generateStory({required String memoryId});
}

class MockAiProvider implements AiService {
  const MockAiProvider();
  @override
  Future<String> generateMemoryTitle({required String memoryId}) async =>
      'A summer worth remembering';
  @override
  Future<String> generateMemorySummary({required String memoryId}) async =>
      'A small collection of moments, kept close to home.';
  @override
  Future<String> generateStory({required String memoryId}) async =>
      'The story is still yours to discover.';
}

class RemoteAiProvider implements AiService {
  @override
  Future<String> generateMemoryTitle({required String memoryId}) =>
      throw UnimplementedError(
        'Remote provider is intentionally deferred beyond Sprint 0.',
      );
  @override
  Future<String> generateMemorySummary({required String memoryId}) =>
      throw UnimplementedError(
        'Remote provider is intentionally deferred beyond Sprint 0.',
      );
  @override
  Future<String> generateStory({required String memoryId}) =>
      throw UnimplementedError(
        'Remote provider is intentionally deferred beyond Sprint 0.',
      );
}

class LocalAiProvider extends RemoteAiProvider {}
