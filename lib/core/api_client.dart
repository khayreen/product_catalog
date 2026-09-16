import 'package:dio/dio.dart';

/// Builds the single [Dio] instance the data layer shares.
///
/// Base URL and timeouts live here so no other file knows the host.
/// The timeouts matter: without them a request on a dead network hangs
/// forever and the UI sits in its loading state permanently.
Dio createApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://dummyjson.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
    ),
  );
}
