import 'package:bloc/bloc.dart';
import 'package:core_bloc/base/base_state.dart';

abstract class BaseBloc<E, S extends BaseState> extends Bloc<E, S> {
  BaseBloc(super.initialState);

  S loadingState() => state.copyWith(status: ViewStatus.loading) as S;

  S successState({String? message}) =>
      state.copyWith(status: ViewStatus.success, message: message) as S;

  S failureState({String? message}) =>
      state.copyWith(status: ViewStatus.failure, message: message) as S;
}
