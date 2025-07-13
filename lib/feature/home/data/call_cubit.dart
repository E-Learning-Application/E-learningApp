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
  final bool isVideoToggling;
  final bool isAudioToggling; // Add this for smooth audio transitions

  CallConnected({
    required this.matchType,
    required this.targetUserId,
    required this.isVideo,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isSpeakerOn = false,
    this.localStream,
    this.remoteStream,
    this.isVideoToggling = false,
    this.isAudioToggling = false,
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
    bool? isVideoToggling,
    bool? isAudioToggling,
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
      isVideoToggling: isVideoToggling ?? this.isVideoToggling,
      isAudioToggling: isAudioToggling ?? this.isAudioToggling,
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
  bool _isVideoToggling = false;
  bool _isAudioToggling = false;

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

      // Don't emit ended state if we're just toggling video or audio
      if (callState == CallState.ended &&
          (_isVideoToggling || _isAudioToggling)) {
        log('🔄 Ignoring call ended during toggle operation');
        return;
      }

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
        if (state is! CallConnecting &&
            !_isVideoToggling &&
            !_isAudioToggling) {
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

        if (targetUserId.isEmpty) {
          log('⚠️ Cannot emit connected state: no target user ID');
          return;
        }

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
            isVideoToggling: false,
            isAudioToggling: false,
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
            isVideoToggling: false,
            isAudioToggling: false,
          ));
          log('✅ Emitted new CallConnected state');
        }

        // Reset toggle flags after successful connection
        _isVideoToggling = false;
        _isAudioToggling = false;
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

  void resetCallState() {
    log('🔄 Resetting call state to initial');
    emit(CallInitial());
  }

  // FIXED: Smooth mute toggle without state emission
  Future<void> toggleMute() async {
    try {
      if (state is! CallConnected) {
        log('⚠️ Cannot toggle mute: not in connected state');
        return;
      }

      final currentState = state as CallConnected;

      // Set audio toggling flag first
      _isAudioToggling = true;

      // Show immediate UI feedback
      emit(currentState.copyWith(
        isAudioToggling: true,
        isMuted: !currentState.isMuted, // Immediate UI update
      ));

      log('🔇 Toggling mute, current muted: ${currentState.isMuted}');

      // Perform the actual audio toggle
      await _webRTCService.toggleAudio();

      // Update state with final result
      emit(currentState.copyWith(
        isMuted: !_webRTCService.isAudioEnabled,
        isAudioToggling: false,
      ));

      _isAudioToggling = false;
      log('🔇 Audio toggled successfully: muted = ${!_webRTCService.isAudioEnabled}');
    } catch (e) {
      _isAudioToggling = false;
      log('❌ Failed to toggle audio: $e');

      // Revert UI state on error
      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(currentState.copyWith(
          isMuted: _webRTCService.isAudioEnabled,
          isAudioToggling: false,
        ));
      }
    }
  }

  // FIXED: Smooth video toggle without renegotiation
  Future<void> toggleVideo() async {
    try {
      if (state is! CallConnected) {
        log('⚠️ Cannot toggle video: not in connected state');
        return;
      }

      final currentState = state as CallConnected;

      // Set video toggling flag first
      _isVideoToggling = true;

      // Show immediate UI feedback
      emit(currentState.copyWith(
        isVideoToggling: true,
        isVideoOff: !currentState.isVideoOff, // Immediate UI update
      ));

      log('📹 Toggling video, current video off: ${currentState.isVideoOff}');

      // Perform the actual video toggle
      await _webRTCService.toggleVideo();

      // Update state with final result
      emit(currentState.copyWith(
        isVideoOff: !_webRTCService.isVideoEnabled,
        isVideoToggling: false,
      ));

      _isVideoToggling = false;
      log('📹 Video toggled successfully: off = ${!_webRTCService.isVideoEnabled}');
    } catch (e) {
      _isVideoToggling = false;
      log('❌ Failed to toggle video: $e');

      // Revert UI state on error
      if (state is CallConnected) {
        final currentState = state as CallConnected;
        emit(currentState.copyWith(
          isVideoOff: !_webRTCService.isVideoEnabled,
          isVideoToggling: false,
        ));
      }
    }
  }

  // IMPROVED: Better video mode switching
  Future<void> switchVideoMode() async {
    try {
      if (state is! CallConnected) {
        log('⚠️ Cannot switch video mode: not in connected state');
        return;
      }

      final currentState = state as CallConnected;
      final currentUserId = _webRTCService.currentCallUserId;

      if (currentUserId == null) {
        log('❌ No current call user ID for switching video mode');
        return;
      }

      _isVideoToggling = true;

      // Show switching state
      emit(currentState.copyWith(isVideoToggling: true));

      log('🔄 Switching video mode from ${currentState.isVideo ? 'video' : 'voice'} to ${!currentState.isVideo ? 'video' : 'voice'}');

      // End current call quietly
      await _webRTCService.endCall();

      // Small delay for cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Start new call with opposite mode
      if (currentState.isVideo) {
        await _webRTCService.startAudioCall(currentUserId);
      } else {
        await _webRTCService.startVideoCall(currentUserId);
      }

      log('✅ Video mode switch completed');
    } catch (e) {
      _isVideoToggling = false;
      log('❌ Failed to switch video mode: $e');
      emit(CallFailed(error: 'Failed to switch video mode: $e'));
    }
  }

  // FIXED: Smooth speaker toggle
  Future<void> toggleSpeaker() async {
    try {
      if (state is! CallConnected) {
        log('⚠️ Cannot toggle speaker: not in connected state');
        return;
      }

      final currentState = state as CallConnected;

      // Immediate UI update
      emit(currentState.copyWith(
        isSpeakerOn: !currentState.isSpeakerOn,
      ));

      log('🔊 Speaker toggled to: ${!currentState.isSpeakerOn}');

      // Here you would call the actual speaker toggle method if available
      // await _webRTCService.toggleSpeaker();
    } catch (e) {
      log('❌ Failed to toggle speaker: $e');
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

  // Getters
  MediaStream? get localStream => _localStream ?? _webRTCService.localStream;
  MediaStream? get remoteStream => _remoteStream ?? _webRTCService.remoteStream;
  bool get isInCall => _webRTCService.isInCall;
  bool get isVideoCall => _webRTCService.isVideoCall;
  bool get isVideoEnabled => _webRTCService.isVideoEnabled;
  bool get isAudioEnabled => _webRTCService.isAudioEnabled;
  String? get currentCallUserId => _webRTCService.currentCallUserId;
  bool get isVideoToggling => _isVideoToggling;
  bool get isAudioToggling => _isAudioToggling;

  // Utility methods
  bool get hasLocalStream => localStream != null;
  bool get hasRemoteStream => remoteStream != null;
  bool get isCallActive => state is CallConnected;
  bool get isCallInProgress =>
      state is CallConnecting || state is CallConnected;

  String get callStatusText {
    if (state is CallConnected) {
      final connectedState = state as CallConnected;
      if (connectedState.isVideoToggling) {
        return 'Switching video...';
      }
      if (connectedState.isAudioToggling) {
        return 'Switching audio...';
      }
      return 'Connected';
    }

    switch (state.runtimeType) {
      case CallInitial:
        return 'Ready';
      case CallConnecting:
        return 'Connecting...';
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
