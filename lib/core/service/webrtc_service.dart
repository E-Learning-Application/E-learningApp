import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:e_learning_app/core/service/signalr_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  SignalRService? _signalRService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _isInCall = false;
  bool _isVideoCall = false;
  String? _currentCallUserId;
  String? _currentCallId;
  bool _isIncomingCall = false;

  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();
  final StreamController<IncomingCall> _incomingCallController =
      StreamController<IncomingCall>.broadcast();

  Stream<MediaStream> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;
  Stream<CallState> get onCallStateChanged => _callStateController.stream;
  Stream<IncomingCall> get onIncomingCall => _incomingCallController.stream;

  final Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan'
  };

  final Map<String, dynamic> _rtcConstraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  Future<void> initialize(SignalRService signalRService) async {
    try {
      _signalRService = signalRService;
      _signalRService!.onWebRtcSignal.listen((signalData) {
        _handleWebRtcSignal(signalData);
      });

      log('WebRTC Service initialized');
    } catch (e) {
      log('WebRTC initialization error: $e');
      throw Exception('Failed to initialize WebRTC: $e');
    }
  }

  Future<void> startVideoCall(String targetUserId) async {
    await _initiateCall(targetUserId, true);
  }

  Future<void> startAudioCall(String targetUserId) async {
    await _initiateCall(targetUserId, false);
  }

  Future<void> _initiateCall(String targetUserId, bool isVideo) async {
    try {
      if (_isInCall) {
        throw Exception('Already in a call');
      }

      _isVideoCall = isVideo;
      _currentCallUserId = targetUserId;
      _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
      _isIncomingCall = false;

      _callStateController.add(CallState.connecting);

      await _requestPermissions(isVideo);
      await _createPeerConnection();
      await _getUserMedia(isVideo);
      await _createOffer();

      _isInCall = true;
      log('Call initiated to user: $targetUserId');
    } catch (e) {
      log('Failed to initiate call: $e');
      _callStateController.add(CallState.failed);
      throw Exception('Failed to start call: $e');
    }
  }

  Future<void> acceptIncomingCall(String callerId, bool isVideo) async {
    try {
      _isVideoCall = isVideo;
      _currentCallUserId = callerId;
      _isIncomingCall = false;

      _callStateController.add(CallState.connecting);

      await _requestPermissions(isVideo);
      await _createPeerConnection();
      await _getUserMedia(isVideo);
      await _processPendingOffer();

      _isInCall = true;
      log('Incoming call accepted from user: $callerId');
    } catch (e) {
      log('Failed to accept call: $e');
      _callStateController.add(CallState.failed);
      throw Exception('Failed to accept call: $e');
    }
  }

  Future<void> rejectIncomingCall() async {
    try {
      if (_currentCallUserId != null) {
        await _sendWebRtcSignal(_currentCallUserId!, {
          'type': 'reject',
          'callId': _currentCallId,
        });
      }

      _resetCall();
      _callStateController.add(CallState.ended);
      log('Incoming call rejected');
    } catch (e) {
      log('Failed to reject call: $e');
    }
  }

  Future<void> endCall() async {
    try {
      if (_currentCallUserId != null) {
        await _sendWebRtcSignal(_currentCallUserId!, {
          'type': 'end',
          'callId': _currentCallId,
        });
      }

      _resetCall();
      _callStateController.add(CallState.ended);
      log('Call ended');
    } catch (e) {
      log('Failed to end call: $e');
    }
  }

  Future<void> toggleVideo() async {
    try {
      if (_localStream != null) {
        final videoTrack = _localStream!.getVideoTracks().first;
        videoTrack.enabled = !videoTrack.enabled;
        log('Video toggled: ${videoTrack.enabled}');
      }
    } catch (e) {
      log('Failed to toggle video: $e');
    }
  }

  Future<void> toggleAudio() async {
    try {
      if (_localStream != null) {
        final audioTrack = _localStream!.getAudioTracks().first;
        audioTrack.enabled = !audioTrack.enabled;
        log('Audio toggled: ${audioTrack.enabled}');
      }
    } catch (e) {
      log('Failed to toggle audio: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      if (_localStream != null) {
        final videoTrack = _localStream!.getVideoTracks().first;
        await Helper.switchCamera(videoTrack);
        log('Camera switched');
      }
    } catch (e) {
      log('Failed to switch camera: $e');
    }
  }

  Future<void> _requestPermissions(bool isVideo) async {
    try {
      final permissions = <Permission>[Permission.microphone];
      if (isVideo) {
        permissions.add(Permission.camera);
      }

      final statuses = await permissions.request();

      for (final permission in permissions) {
        if (statuses[permission] != PermissionStatus.granted) {
          throw Exception('Permission denied: $permission');
        }
      }

      log('Permissions granted');
    } catch (e) {
      log('Permission request failed: $e');
      throw Exception('Failed to get permissions: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection =
          await createPeerConnection(_rtcConfiguration, _rtcConstraints);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendWebRtcSignal(_currentCallUserId!, {
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
        });
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        log('onTrack event received with ${event.streams.length} streams');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream!);
          _callStateController.add(CallState.connected);
          log('Remote track added - stream ID: ${_remoteStream!.id}');
        } else {
          log('onTrack event received but no streams available');
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        log('WebRTC Connection state changed to: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            log('WebRTC connection established - emitting CallState.connected');
            _callStateController.add(CallState.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            log('WebRTC connection disconnected - emitting CallState.failed');
            _callStateController.add(CallState.failed);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            log('WebRTC connection failed - emitting CallState.failed');
            _callStateController.add(CallState.failed);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            log('WebRTC connection closed - emitting CallState.ended');
            _callStateController.add(CallState.ended);
            break;
          default:
            log('WebRTC connection state: $state (no action taken)');
            break;
        }
      };

      log('Peer connection created');
    } catch (e) {
      log('Failed to create peer connection: $e');
      throw Exception('Failed to create peer connection: $e');
    }
  }

  Future<void> _getUserMedia(bool isVideo) async {
    try {
      final constraints = <String, dynamic>{
        'audio': true,
        'video': isVideo
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream!);

      if (_peerConnection != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      log('Local stream obtained');
    } catch (e) {
      log('Failed to get user media: $e');
      throw Exception('Failed to get user media: $e');
    }
  }

  Future<void> _createOffer() async {
    try {
      log('Creating offer for user: $_currentCallUserId');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'offer',
        'offer': offer.toMap(),
        'callId': _currentCallId,
        'isVideo': _isVideoCall,
      });

      log('Offer created and sent to user: $_currentCallUserId');
    } catch (e) {
      log('Failed to create offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  Future<void> _createAnswer() async {
    try {
      log('Creating answer for user: $_currentCallUserId');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'answer',
        'answer': answer.toMap(),
        'callId': _currentCallId,
      });

      log('Answer created and sent to user: $_currentCallUserId');
    } catch (e) {
      log('Failed to create answer: $e');
      throw Exception('Failed to create answer: $e');
    }
  }

  void _handleWebRtcSignal(String signalData) async {
    try {
      final signal = jsonDecode(signalData);
      final type = signal['type'];

      log('Received WebRTC signal: $type');

      switch (type) {
        case 'offer':
          await _handleOffer(signal);
          break;
        case 'answer':
          await _handleAnswer(signal);
          break;
        case 'ice-candidate':
          await _handleIceCandidate(signal);
          break;
        case 'reject':
          _handleReject();
          break;
        case 'end':
          _handleEnd();
          break;
        default:
          log('Unknown signal type: $type');
      }
    } catch (e) {
      log('Error handling WebRTC signal: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> signal) async {
    try {
      final offer = signal['offer'];
      final callId = signal['callId'];
      final isVideo = signal['isVideo'] ?? false;
      final callerId = signal['callerId'] ?? 'unknown';

      if (_isInCall) {
        await _sendWebRtcSignal(callerId, {
          'type': 'reject',
          'callId': callId,
        });
        return;
      }

      _incomingCallController.add(IncomingCall(
        callerId: callerId,
        callId: callId,
        isVideo: isVideo,
      ));

      _pendingOffer = RTCSessionDescription(offer['sdp'], offer['type']);
      _currentCallId = callId;
      _currentCallUserId = callerId;
      _isIncomingCall = true;

      log('Incoming call offer received from: $callerId');
    } catch (e) {
      log('Error handling offer: $e');
    }
  }

  RTCSessionDescription? _pendingOffer;

  Future<void> _handleAnswer(Map<String, dynamic> signal) async {
    try {
      final answer = signal['answer'];
      final rtcAnswer = RTCSessionDescription(answer['sdp'], answer['type']);

      log('Processing answer from remote peer');
      await _peerConnection!.setRemoteDescription(rtcAnswer);
      log('Answer processed successfully');
    } catch (e) {
      log('Error handling answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> signal) async {
    try {
      final candidateData = signal['candidate'];
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await _peerConnection!.addCandidate(candidate);
      log('ICE candidate added');
    } catch (e) {
      log('Error handling ICE candidate: $e');
    }
  }

  void _handleReject() {
    _resetCall();
    _callStateController.add(CallState.rejected);
    log('Call rejected by remote user');
  }

  void _handleEnd() {
    _resetCall();
    _callStateController.add(CallState.ended);
    log('Call ended by remote user');
  }

  Future<void> _processPendingOffer() async {
    if (_pendingOffer != null) {
      await _peerConnection!.setRemoteDescription(_pendingOffer!);
      await _createAnswer();
      _pendingOffer = null;
    }
  }

  Future<void> _sendWebRtcSignal(
      String targetUserId, Map<String, dynamic> signal) async {
    try {
      if (_signalRService == null) {
        throw Exception('SignalR service not initialized');
      }

      final signalData = jsonEncode(signal);
      await _signalRService!.sendWebRtcSignal(
        targetUserId: targetUserId,
        signalData: signalData,
      );
    } catch (e) {
      log('Failed to send WebRTC signal: $e');
      throw Exception('Failed to send signal: $e');
    }
  }

  void _resetCall() {
    _isInCall = false;
    _isVideoCall = false;
    _currentCallUserId = null;
    _currentCallId = null;
    _isIncomingCall = false;
    _pendingOffer = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection = null;
  }

  bool get isInCall => _isInCall;
  bool get isVideoCall => _isVideoCall;
  String? get currentCallUserId => _currentCallUserId;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  void dispose() {
    _resetCall();
    _localStreamController.close();
    _remoteStreamController.close();
    _callStateController.close();
    _incomingCallController.close();
  }
}

enum CallState {
  idle,
  connecting,
  connected,
  ended,
  rejected,
  failed,
}

class IncomingCall {
  final String callerId;
  final String callId;
  final bool isVideo;

  IncomingCall({
    required this.callerId,
    required this.callId,
    required this.isVideo,
  });
}
