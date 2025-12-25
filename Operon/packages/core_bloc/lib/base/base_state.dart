enum ViewStatus { initial, loading, success, failure }

abstract class BaseState {
  const BaseState({
    this.status = ViewStatus.initial,
    this.message,
  });

  final ViewStatus status;
  final String? message;

  BaseState copyWith({
    ViewStatus? status,
    String? message,
  });
}
