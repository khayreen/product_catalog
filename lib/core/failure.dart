/// What the UI is allowed to know about a failed request.
///
/// The presentation layer never sees a DioException or a status code — it
/// sees one of these, with a message already written for a person.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// Shown directly to the user.
  final String message;
}

/// The request never reached the server: no connection, or it timed out.
class NetworkFailure extends Failure {
  const NetworkFailure()
    : super('No connection. Check your network and try again.');
}

/// The server answered, but with an error status.
class ServerFailure extends Failure {
  const ServerFailure(this.statusCode)
    : super('The server could not handle that request. Please try again.');

  final int? statusCode;
}

/// Anything else, including a response that could not be parsed.
class UnknownFailure extends Failure {
  const UnknownFailure() : super('Something went wrong. Please try again.');
}

/// Not a failure the user should ever see.
///
/// The app abandoned this request itself because a newer one replaced it —
/// which is what the debounced search does on every keystroke. Showing an
/// error state for it would be a bug, so it is deliberately not a [Failure].
class RequestCancelled implements Exception {
  const RequestCancelled();
}
