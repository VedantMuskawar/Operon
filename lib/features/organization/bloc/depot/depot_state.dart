import 'package:equatable/equatable.dart';

import '../../../../core/models/depot_location.dart';

class DepotState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final bool saveSuccess;
  final String? errorMessage;
  final DepotLocation? location;

  const DepotState({
    this.isLoading = false,
    this.isSaving = false,
    this.saveSuccess = false,
    this.errorMessage,
    this.location,
  });

  DepotState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? saveSuccess,
    String? errorMessage,
    DepotLocation? location,
    bool clearError = false,
    bool clearSuccess = false,
    bool overrideLocation = false,
  }) {
    return DepotState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      saveSuccess: clearSuccess ? false : (saveSuccess ?? this.saveSuccess),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      location: overrideLocation ? location : (location ?? this.location),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        saveSuccess,
        errorMessage,
        location,
      ];

  static DepotState initial() => const DepotState();
}


