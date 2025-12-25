import 'package:dash_mobile/data/services/call_detection_service.dart';
import 'package:dash_mobile/data/services/caller_id_service.dart';
import 'package:dash_mobile/data/services/call_overlay_manager.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'call_detection_state.dart';

class CallDetectionCubit extends Cubit<CallDetectionState> {
  CallDetectionCubit({
    required CallDetectionService callDetectionService,
    required CallerIdService callerIdService,
    required CallOverlayManager overlayManager,
    required OrganizationContextCubit orgContextCubit,
  })  : _callDetectionService = callDetectionService,
        _callerIdService = callerIdService,
        _overlayManager = overlayManager,
        _orgContextCubit = orgContextCubit,
        super(const CallDetectionState()) {
    _initialize();
  }

  final CallDetectionService _callDetectionService;
  final CallerIdService _callerIdService;
  final CallOverlayManager _overlayManager;
  final OrganizationContextCubit _orgContextCubit;

  void _initialize() {
    // Listen to incoming calls
    _callDetectionService.incomingCalls.listen(_handleIncomingCall);
    
    // Listen to call end events
    _callDetectionService.callEnds.listen((_) => onCallEnded());
    
    // Start listening for calls
    _callDetectionService.startListening().then((success) {
      if (success) {
        emit(state.copyWith(isListening: true));
      }
    });
  }

  Future<void> _handleIncomingCall(String phoneNumber) async {
    if (kDebugMode) {
      debugPrint('[CallDetectionCubit] Incoming call detected: $phoneNumber');
    }

    // Normalize phone number
    final normalizedNumber = phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    if (normalizedNumber.isEmpty) {
      if (kDebugMode) {
        debugPrint('[CallDetectionCubit] Phone number is empty, cannot identify caller');
      }
      return;
    }

    final organization = _orgContextCubit.state.organization;
    if (organization == null) {
      if (kDebugMode) {
        debugPrint('[CallDetectionCubit] No organization selected');
      }
      return;
    }

    emit(state.copyWith(isProcessing: true));

    try {
      // Get caller data
      if (kDebugMode) {
        debugPrint('[CallDetectionCubit] Looking up caller data for: $normalizedNumber');
      }

      final callerData = await _callerIdService.getCallerData(
        normalizedNumber,
        organization.id,
      );

      if (callerData != null) {
        if (kDebugMode) {
          debugPrint('[CallDetectionCubit] Client found: ${callerData.clientName}');
          debugPrint('[CallDetectionCubit] Pending orders: ${callerData.pendingOrders.length}');
          debugPrint('[CallDetectionCubit] Completed orders: ${callerData.completedOrders.length}');
        }

        // Show overlay
        if (kDebugMode) {
          debugPrint('[CallDetectionCubit] Attempting to show overlay...');
        }

        final shown = await _overlayManager.showOverlay(
          clientId: callerData.clientId,
          clientName: callerData.clientName,
          clientPhone: callerData.clientPhone,
          pendingOrders: callerData.pendingOrders,
          completedOrders: callerData.completedOrders,
        );

        if (kDebugMode) {
          debugPrint('[CallDetectionCubit] Overlay shown: $shown');
        }

        if (shown) {
          emit(state.copyWith(
            isProcessing: false,
            currentCaller: callerData,
            isOverlayVisible: true,
          ));
        } else {
          if (kDebugMode) {
            debugPrint('[CallDetectionCubit] Failed to show overlay');
          }
          emit(state.copyWith(isProcessing: false));
        }
      } else {
        if (kDebugMode) {
          debugPrint('[CallDetectionCubit] Caller not found in clients');
        }
        emit(state.copyWith(isProcessing: false));
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[CallDetectionCubit] Error handling incoming call: $e');
        debugPrint('[CallDetectionCubit] Stack trace: $stackTrace');
      }
      emit(state.copyWith(isProcessing: false));
    }
  }

  /// Handle call end - hide overlay
  Future<void> onCallEnded() async {
    if (kDebugMode) {
      debugPrint('[CallDetectionCubit] Call ended, hiding overlay');
    }
    await _overlayManager.hideOverlay();
    emit(state.copyWith(
      isOverlayVisible: false,
      currentCaller: null,
    ));
  }

  /// Test overlay (for debugging)
  Future<void> testOverlay() async {
    if (kDebugMode) {
      debugPrint('[CallDetectionCubit] Testing overlay...');
    }
    final shown = await _overlayManager.testOverlay();
    if (kDebugMode) {
      debugPrint('[CallDetectionCubit] Test overlay result: $shown');
    }
  }

  @override
  Future<void> close() {
    _callDetectionService.dispose();
    return super.close();
  }
}

