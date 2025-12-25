part of 'call_detection_cubit.dart';

class CallDetectionState {
  const CallDetectionState({
    this.isListening = false,
    this.isProcessing = false,
    this.isOverlayVisible = false,
    this.currentCaller,
  });

  final bool isListening;
  final bool isProcessing;
  final bool isOverlayVisible;
  final CallerIdData? currentCaller;

  CallDetectionState copyWith({
    bool? isListening,
    bool? isProcessing,
    bool? isOverlayVisible,
    CallerIdData? currentCaller,
  }) {
    return CallDetectionState(
      isListening: isListening ?? this.isListening,
      isProcessing: isProcessing ?? this.isProcessing,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      currentCaller: currentCaller ?? this.currentCaller,
    );
  }
}

