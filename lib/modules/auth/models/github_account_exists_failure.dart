import 'package:test_point/core/error/failure.dart';

/// Linking GitHub to the guest failed because that GitHub account already has
/// an API Caffeine account. The Account dialog offers to sign in to it instead.
class GitHubAccountExistsFailure extends AuthFailure {
  const GitHubAccountExistsFailure()
    : super('This GitHub account already has an API Caffeine account.');
}
