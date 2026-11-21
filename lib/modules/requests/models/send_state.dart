import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';

/// What the response pane shows.
sealed class SendState {
  const SendState();
}

class SendIdle extends SendState {
  const SendIdle();
}

class SendLoading extends SendState {
  const SendLoading();
}

class SendSuccess extends SendState {
  const SendSuccess(this.response);
  final HttpResponseResult response;
}

class SendFailed extends SendState {
  const SendFailed(this.failure);
  final Failure failure;
}
