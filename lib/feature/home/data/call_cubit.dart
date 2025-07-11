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
  final MediaStream? localStream;
  final MediaStream? remoteStream;

  CallConnected({
    required this.matchType,
    required this.targetUserId,
    required this.isVideo,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isSpeakerOn = false,
    this.localStream,
    this.remoteStream,
  });

  CallConnected copyWith({
    String? matchType,
    String? targetUserId,
    bool? isVideo,
    bool? isMuted,
    bool? isVideoOff,
    bool? isSpeakerOn,
    MediaStream? localStream,
    MediaStream? remoteStream,
  }) {
    return CallConnected(
      matchType: matchType ?? this.matchType,
      targetUserId: targetUserId ?? this.targetUserId,
      isVideo: isVideo ?? this.isVideo,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
    );
  }
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
      log('✅ WebRTC service initialized successfully in CallCubit');
    } catch (e) {
      log('❌ Failed to initialize WebRTC service: $e');
      emit(CallFailed(error: 'Failed to initialize WebRTC: $e'));
    }
  }

  void _setupListeners() {
    // Listen to call state changes
    _callStateSubscription =
        _webRTCService.onCallStateChanged.listen((callState) {
      log('📞 CallCubit received call state: $callState');
      _handleCallStateChange(callState);
    });

    // Listen to incoming calls
    _incomingCallSubscription =
        _webRTCService.onIncomingCall.listen((incomingCall) {
      log('📞 CallCubit received incoming call from: ${incomingCall.callerId}');
      emit(IncomingCallReceived(
        callerId: incomingCall.callerId,
        callId: incomingCall.callId,
        isVideo: incomingCall.isVideo,
      ));
    });

    // Listen to local stream changes
    _localStreamSubscription = _webRTCService.onLocalStream.listen((stream) {
      log('📺 CallCubit received local stream');
      _localStream = stream;
      _updateStreamInCurrentState();
    });

    // Listen to remote stream changes
    _remoteStreamSubscription = _webRTCService.onRemoteStream.listen((stream) {
      log('📺 CallCubit received remote stream');
      _remoteStream = stream;
      _updateStreamInCurrentState();
    });
  }

  void _updateStreamInCurrentState() {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(currentState.copyWith(
        localStream: _localStream,
        remoteStream: _remoteStream,
      ));
      log('📺 Updated streams in CallConnected state');
    }
  }

  void _handleCallStateChange(CallState callState) {
    log('🔄 Handling call state change: $callState, current cubit state: ${state.runtimeType}');

    switch (callState) {
      case CallState.connecting:
        if (state is! CallConnecting) {
          emit(CallConnecting(
            matchType: _webRTCService.isVideoCall ? 'video' : 'voice',
            targetUserId: _webRTCService.currentCallUserId ?? '',
          ));
          log('✅ Emitted CallConnecting state');
        }
        break;

      case CallState.connected:
        final targetUserId = _webRTCService.currentCallUserId ?? '';
        final isVideo = _webRTCService.isVideoCall;

        if (state is CallConnected) {
          // Update existing connected state
          final currentState = state as CallConnected;
          emit(currentState.copyWith(
            matchType: isVideo ? 'video' : 'voice',
            targetUserId: targetUserId,
            isVideo: isVideo,
            isMuted: !_webRTCService.isAudioEnabled,
            isVideoOff: !_webRTCService.isVideoEnabled,
            localStream: _localStream,
            remoteStream: _remoteStream,
          ));
          log('✅ Updated CallConnected state');
        } else {
          // New connected state
          emit(CallConnected(
            matchType: isVideo ? 'video' : 'voice',
            targetUserId: targetUserId,
            isVideo: isVideo,
            isMuted: !_webRTCService.isAudioEnabled,
            isVideoOff: !_webRTCService.isVideoEnabled,
            localStream: _localStream,
            remoteStream: _remoteStream,
          ));
          log('✅ Emitted new CallConnected state');
        }
        break;

      case CallState.ended:
        _clearStreams();
        emit(CallEnded(reason: 'Call ended'));
        log('✅ Emitted CallEnded state');
        break;

      case CallState.failed:
        _clearStreams();
        emit(CallFailed(error: 'Call failed'));
        log('❌ Emitted CallFailed state');
        break;

      case CallState.rejected:
        _clearStreams();
        emit(CallRejected());
        log('❌ Emitted CallRejected state');
        break;

      default:
        log('❓ Unhandled call state: $callState');
        break;
    }
  }

  void _clearStreams() {
    _localStream = null;
    _remoteStream = null;
  }

  Future<void> startVideoCall(String targetUserId) async {
    try {
      log('🎥 Starting video call to: $targetUserId');
      emit(CallConnecting(matchType: 'video', targetUserId: targetUserId));
      await _webRTCService.startVideoCall(targetUserId);
      log('✅ Video call started successfully');
    } catch (e) {
      log('❌ Failed to start video call: $e');
      emit(CallFailed(error: 'Failed to start video call: $e'));
    }
  }

  Future<void> startVoiceCall(String targetUserId) async {
    try {
      log('🎤 Starting voice call to: $targetUserId');
      emit(CallConnecting(matchType: 'voice', targetUserId: targetUserId));
      await _webRTCService.startAudioCall(targetUserId);
      log('✅ Voice call started successfully');
    } catch (e) {
      log('❌ Failed to start voice call: $e');
      emit(CallFailed(error: 'Failed to start voice call: $e'));
    }
  }

  Future<void> acceptIncomingCall(String callerId, bool isVideo) async {
    try {
      log('✅ Accepting incoming call from: $callerId, isVideo: $isVideo');
      await _webRTCService.acceptIncomingCall(callerId, isVideo);
      log('✅ Incoming call accepted successfully');
    } catch (e) {
      log('❌ Failed to accept incoming call: $e');
      emit(CallFailed(error: 'Failed to accept call: $e'));
    }
  }

  Future<void> rejectIncomingCall() async {
    try {
      log('❌ Rejecting incoming call');
      await _webRTCService.rejectIncomingCall();
      emit(CallInitial());
      log('✅ Incoming call rejected successfully');
    } catch (e) {
      log('❌ Failed to reject incoming call: $e');
    }
  }

  Future<void> endCall() async {
    try {
      log('📞 Ending call');
      await _webRTCService.endCall();
      log('✅ Call ended successfully');
    } catch (e) {
      log('❌ Failed to end call: $e');
      emit(CallFailed(error: 'Failed to end call: $e'));
    }
  }

  Future<void> toggleMute() async {
    try {
      log('🔇 Toggling mute, current state: ${state.runtimeType}');
      await _webRTCService.toggleAudio();

      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(currentState.copyWith(
          isMuted: !_webRTCService.isAudioEnabled,
        ));
        log('🔇 Audio toggled: muted = ${!_webRTCService.isAudioEnabled}');
      }
    } catch (e) {
      log('❌ Failed to toggle audio: $e');
    }
  }

  Future<void> toggleVideo() async {
    try {
      log('📹 Toggling video');
      await _webRTCService.toggleVideo();

      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(currentState.copyWith(
          isVideoOff: !_webRTCService.isVideoEnabled,
        ));
        log('📹 Video toggled: off = ${!_webRTCService.isVideoEnabled}');
      }
    } catch (e) {
      log('❌ Failed to toggle video: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(currentState.copyWith(
        isSpeakerOn: !currentState.isSpeakerOn,
      ));
      log('🔊 Speaker toggled: ${!currentState.isSpeakerOn}');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _webRTCService.switchCamera();
      log('📱 Camera switched');
    } catch (e) {
      log('❌ Failed to switch camera: $e');
    }
  }

  MediaStream? get localStream => _localStream ?? _webRTCService.localStream;
  MediaStream? get remoteStream => _remoteStream ?? _webRTCService.remoteStream;
  bool get isInCall => _webRTCService.isInCall;
  bool get isVideoCall => _webRTCService.isVideoCall;
  bool get isVideoEnabled => _webRTCService.isVideoEnabled;
  bool get isAudioEnabled => _webRTCService.isAudioEnabled;
  String? get currentCallUserId => _webRTCService.currentCallUserId;

  // Additional utility methods
  bool get hasLocalStream => localStream != null;
  bool get hasRemoteStream => remoteStream != null;
  bool get isCallActive => state is CallConnected;
  bool get isCallInProgress =>
      state is CallConnecting || state is CallConnected;

  String get callStatusText {
    switch (state.runtimeType) {
      case CallInitial:
        return 'Ready';
      case CallConnecting:
        return 'Connecting...';
      case CallConnected:
        return 'Connected';
      case CallEnded:
        return 'Call Ended';
      case CallFailed:
        return 'Call Failed';
      case CallRejected:
        return 'Call Rejected';
      case IncomingCallReceived:
        return 'Incoming Call';
      default:
        return 'Unknown';
    }
  }

  @override
  Future<void> close() {
    log('🧹 Closing CallCubit and cleaning up subscriptions');
    _callStateSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    return super.close();
  }
}
