library;

import 'package:memory_domain/memory_domain.dart';

abstract interface class MovieRenderer {
  Future<Object> createPreview(MovieProject project);
  Future<Object> renderMovie(MovieProject project);
}

class UnimplementedMovieRenderer implements MovieRenderer {
  @override
  Future<Object> createPreview(MovieProject project) =>
      throw UnimplementedError('Preview rendering is a future boundary.');
  @override
  Future<Object> renderMovie(MovieProject project) =>
      throw UnimplementedError('Movie rendering is a future boundary.');
}
