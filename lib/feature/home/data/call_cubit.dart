import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/core/service/webrtc_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:developer';

// Call States
abstract class CallCubitState {}

class CallInitial extends CallCubitState {}

class CallConnecting extends CallCubitState {
  final String matchType;
  final String targetUserId;

  CallConnecting({required this.matchType, required this.targetUserId});
}

class CallConnected extends CallCubitState {
  final String matchType;
  final String targetUserId;
  final bool isVideo;
  final bool isMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;

  CallConnected({
    required this.matchType,
    required this.targetUserId,
    required this.isVideo,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isSpeakerOn = false,
  });
}

class CallEnded extends CallCubitState {
  final String reason;

  CallEnded({required this.reason});
}

class CallFailed extends CallCubitState {
  final String error;

  CallFailed({required this.error});
}

class CallRejected extends CallCubitState {}

class IncomingCallReceived extends CallCubitState {
  final String callerId;
  final String callId;
  final bool isVideo;

  IncomingCallReceived({
    required this.callerId,
    required this.callId,
    required this.isVideo,
  });
}

// Call Events
abstract class CallEvent {}

class StartVideoCall extends CallEvent {
  final String targetUserId;

  StartVideoCall({required this.targetUserId});
}

class StartVoiceCall extends CallEvent {
  final String targetUserId;

  StartVoiceCall({required this.targetUserId});
}

class AcceptIncomingCall extends CallEvent {
  final String callerId;
  final bool isVideo;

  AcceptIncomingCall({required this.callerId, required this.isVideo});
}

class RejectIncomingCall extends CallEvent {}

class EndCall extends CallEvent {}

class ToggleMute extends CallEvent {}

class ToggleVideo extends CallEvent {}

class ToggleSpeaker extends CallEvent {}

class SwitchCamera extends CallEvent {}

class CallCubit extends Cubit<CallCubitState> {
  final WebRTCService _webRTCService;
  final SignalRService _signalRService;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;

  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallCubit({
    required WebRTCService webRTCService,
    required SignalRService signalRService,
  })  : _webRTCService = webRTCService,
        _signalRService = signalRService,
        super(CallInitial()) {
    _initializeWebRTC();
    _setupListeners();
  }

  Future<void> _initializeWebRTC() async {
    try {
      await _webRTCService.initialize(_signalRService);
      log('WebRTC service initialized successfully');
    } catch (e) {
      log('Failed to initialize WebRTC service: $e');
    }
  }

  void _setupListeners() {
    // Listen to call state changes
    _callStateSubscription =
        _webRTCService.onCallStateChanged.listen((callState) {
      _handleCallStateChange(callState);
    });

    // Listen to incoming calls
    _incomingCallSubscription =
        _webRTCService.onIncomingCall.listen((incomingCall) {
      emit(IncomingCallReceived(
        callerId: incomingCall.callerId,
        callId: incomingCall.callId,
        isVideo: incomingCall.isVideo,
      ));
    });

    // Listen to local stream
    _localStreamSubscription = _webRTCService.onLocalStream.listen((stream) {
      _localStream = stream;
    });

    // Listen to remote stream
    _remoteStreamSubscription = _webRTCService.onRemoteStream.listen((stream) {
      log('Remote stream received in CallCubit');
      _remoteStream = stream;
    });
  }

  void _handleCallStateChange(CallState callState) {
    log('Call state changed to: $callState, current state: ${state.runtimeType}');
    switch (callState) {
      case CallState.connecting:
        if (state is CallConnecting) {
          // Already connecting, do nothing
          log('Already in connecting state');
        } else {
          emit(CallConnecting(
            matchType: _webRTCService.isVideoCall ? 'video' : 'voice',
            targetUserId: _webRTCService.currentCallUserId ?? '',
          ));
          log('Emitted CallConnecting state');
        }
        break;

      case CallState.connected:
        if (state is CallConnected) {
          // Update existing connected state
          final currentState = state as CallConnected;
          emit(CallConnected(
            matchType: _webRTCService.isVideoCall ? 'video' : 'voice',
            targetUserId: _webRTCService.currentCallUserId ?? '',
            isVideo: _webRTCService.isVideoCall,
            isMuted: currentState.isMuted,
            isVideoOff: currentState.isVideoOff,
            isSpeakerOn: currentState.isSpeakerOn,
          ));
          log('Updated CallConnected state');
        } else {
          // New connected state
          emit(CallConnected(
            matchType: _webRTCService.isVideoCall ? 'video' : 'voice',
            targetUserId: _webRTCService.currentCallUserId ?? '',
            isVideo: _webRTCService.isVideoCall,
          ));
          log('Emitted new CallConnected state');
        }
        break;

      case CallState.ended:
        emit(CallEnded(reason: 'Call ended'));
        break;

      case CallState.failed:
        emit(CallFailed(error: 'Call failed'));
        break;

      case CallState.rejected:
        emit(CallRejected());
        break;

      default:
        break;
    }
  }

  Future<void> startVideoCall(String targetUserId) async {
    try {
      emit(CallConnecting(matchType: 'video', targetUserId: targetUserId));

      await _webRTCService.startVideoCall(targetUserId);

      log('Video call started to user: $targetUserId');
    } catch (e) {
      log('Failed to start video call: $e');
      emit(CallFailed(error: 'Failed to start video call: $e'));
    }
  }

  Future<void> startVoiceCall(String targetUserId) async {
    try {
      emit(CallConnecting(matchType: 'voice', targetUserId: targetUserId));

      await _webRTCService.startAudioCall(targetUserId);

      log('Voice call started to user: $targetUserId');
    } catch (e) {
      log('Failed to start voice call: $e');
      emit(CallFailed(error: 'Failed to start voice call: $e'));
    }
  }

  Future<void> acceptIncomingCall(String callerId, bool isVideo) async {
    try {
      await _webRTCService.acceptIncomingCall(callerId, isVideo);

      log('Incoming call accepted from user: $callerId');
    } catch (e) {
      log('Failed to accept incoming call: $e');
      emit(CallFailed(error: 'Failed to accept call: $e'));
    }
  }

  Future<void> rejectIncomingCall() async {
    try {
      await _webRTCService.rejectIncomingCall();
      emit(CallInitial());

      log('Incoming call rejected');
    } catch (e) {
      log('Failed to reject incoming call: $e');
    }
  }

  Future<void> endCall() async {
    try {
      await _webRTCService.endCall();
      emit(CallEnded(reason: 'Call ended by user'));

      log('Call ended');
    } catch (e) {
      log('Failed to end call: $e');
    }
  }

  Future<void> toggleMute() async {
    try {
      log('ToggleMute called, current state: ${state.runtimeType}');
      await _webRTCService.toggleAudio();

      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(CallConnected(
          matchType: currentState.matchType,
          targetUserId: currentState.targetUserId,
          isVideo: currentState.isVideo,
          isMuted: !currentState.isMuted,
          isVideoOff: currentState.isVideoOff,
          isSpeakerOn: currentState.isSpeakerOn,
        ));
        log('Audio toggled in connected state');
      } else if (state is CallConnecting) {
        final currentState = state as CallConnecting;
        emit(CallConnecting(
          matchType: currentState.matchType,
          targetUserId: currentState.targetUserId,
        ));
        log('Audio toggled in connecting state');
      } else {
        log('ToggleMute: unexpected state ${state.runtimeType}');
      }

      log('Audio toggled');
    } catch (e) {
      log('Failed to toggle audio: $e');
    }
  }

  Future<void> toggleVideo() async {
    try {
      await _webRTCService.toggleVideo();

      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(CallConnected(
          matchType: currentState.matchType,
          targetUserId: currentState.targetUserId,
          isVideo: currentState.isVideo,
          isMuted: currentState.isMuted,
          isVideoOff: !currentState.isVideoOff,
          isSpeakerOn: currentState.isSpeakerOn,
        ));
      } else if (state is CallConnecting) {
        final currentState = state as CallConnecting;
        emit(CallConnecting(
          matchType: currentState.matchType,
          targetUserId: currentState.targetUserId,
        ));
      }

      log('Video toggled');
    } catch (e) {
      log('Failed to toggle video: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(CallConnected(
        matchType: currentState.matchType,
        targetUserId: currentState.targetUserId,
        isVideo: currentState.isVideo,
        isMuted: currentState.isMuted,
        isVideoOff: currentState.isVideoOff,
        isSpeakerOn: !currentState.isSpeakerOn,
      ));

      log('Speaker toggled');
    } else if (state is CallConnecting) {
      final currentState = state as CallConnecting;
      emit(CallConnecting(
        matchType: currentState.matchType,
        targetUserId: currentState.targetUserId,
      ));

      log('Speaker toggled (connecting state)');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _webRTCService.switchCamera();
      log('Camera switched');
    } catch (e) {
      log('Failed to switch camera: $e');
    }
  }

  // Getters
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isInCall => _webRTCService.isInCall;
  bool get isVideoCall => _webRTCService.isVideoCall;
  String? get currentCallUserId => _webRTCService.currentCallUserId;

  @override
  Future<void> close() {
    _callStateSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    return super.close();
  }
}
