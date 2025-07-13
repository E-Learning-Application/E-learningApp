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

  void _magentaLog(String msg) {
    print('\u001b[35m[WEBRTC DEBUG] $msg\u001b[0m');
  }

  SignalRService? _signalRService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _isInCall = false;
  bool _isVideoCall = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  String? _currentCallUserId;
  String? _currentCallId;
  bool _isIncomingCall = false;
  RTCSessionDescription? _pendingOffer;
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  // Video toggle state
  bool _isVideoToggling = false;
  bool _hasVideoTrack = false;

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
      {'urls': 'stun:stun3.l.google.com:19302'},
      // Add TURN servers for better connectivity
      // {'urls': 'turn:your-turn-server.com:3478', 'username': 'user', 'credential': 'pass'},
    ],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'enableDscp': true,
    'iceCandidatePoolSize': 10, // Improve ICE gathering
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
      if (!_signalRService!.isConnected &&
          _signalRService!.currentUserId != null &&
          _signalRService!.accessToken != null) {
        await _signalRService!.initialize(
          userId: _signalRService!.currentUserId!,
          accessToken: _signalRService!.accessToken!,
          enableAutoReconnect: true,
        );
      }
      _signalRService!.onWebRtcSignal.listen((signalData) {
        _handleWebRtcSignal(signalData);
      });

      _magentaLog(
          'WebRTC Service initialized, SignalR connected: ${_signalRService!.isConnected}');
    } catch (e) {
      _magentaLog('WebRTC initialization error: $e');
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

      // Check if we're already trying to call this user
      if (_currentCallUserId == targetUserId && _currentCallId != null) {
        _magentaLog(
            '⚠️ Already initiating call to $targetUserId, ignoring duplicate request');
        return;
      }

      _isVideoCall = isVideo;
      _isVideoEnabled = isVideo;
      _isAudioEnabled = true;
      _currentCallUserId = targetUserId;
      _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
      _isIncomingCall = false;
      _hasVideoTrack = isVideo;

      _magentaLog(
          'Starting ${isVideo ? 'video' : 'audio'} call to $targetUserId');
      _callStateController.add(CallState.connecting);

      await _requestPermissions(isVideo);
      await _createPeerConnection();
      await _getUserMedia(isVideo);
      await _createOfferWithTimeout();

      _isInCall = true;
      _magentaLog('Call initiated to user: $targetUserId');
    } catch (e) {
      _magentaLog('Failed to initiate call: $e');
      _callStateController.add(CallState.failed);
      await _cleanupCall();
      throw Exception('Failed to start call: $e');
    }
  }

  Future<void> acceptIncomingCall(String callerId, bool isVideo) async {
    try {
      if (_isInCall) {
        throw Exception('Already in a call');
      }

      if (_pendingOffer == null) {
        _magentaLog('❌ No pending offer available for caller: $callerId');
        _callStateController.add(CallState.failed);
        throw Exception('No pending offer to accept');
      }

      _isVideoCall = isVideo;
      _isVideoEnabled = isVideo;
      _isAudioEnabled = true;
      _currentCallUserId = callerId;
      _isIncomingCall = false;
      _hasVideoTrack = isVideo;

      _magentaLog(
          'Accepting ${isVideo ? 'video' : 'audio'} call from $callerId');
      _callStateController.add(CallState.connecting);

      await _requestPermissions(isVideo);
      await _createPeerConnection();
      await _getUserMedia(isVideo);
      await _processPendingOffer();
      await _createAnswer();

      _isInCall = true;
      _magentaLog('Incoming call accepted from user: $callerId');

      // Add a small delay before emitting connected state
      await Future.delayed(const Duration(milliseconds: 300));
      _callStateController.add(CallState.connected);
    } catch (e) {
      _magentaLog('Failed to accept call: $e');
      _callStateController.add(CallState.failed);
      await _cleanupCall();
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

      await _cleanupCall();
      _callStateController.add(CallState.rejected);
      _magentaLog('Incoming call rejected');
    } catch (e) {
      _magentaLog('Failed to reject call: $e');
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

      await _cleanupCall();
      _callStateController.add(CallState.ended);
      _magentaLog('Call ended');
    } catch (e) {
      _magentaLog('Failed to end call: $e');
    }
  }

  // Enhanced video toggle with smooth transition
  Future<void> toggleVideo() async {
    if (!_isInCall || _isVideoToggling) {
      _magentaLog('Cannot toggle video: not in call or already toggling');
      return;
    }

    try {
      _isVideoToggling = true;
      _magentaLog('🔄 Toggling video: current state = $_isVideoEnabled');

      if (_hasVideoTrack) {
        // Simply enable/disable existing video track
        await _toggleVideoTrack();
      } else {
        // Need to add video track for the first time
        await _addVideoTrack();
      }

      _magentaLog('✅ Video toggle completed');
    } catch (e) {
      _magentaLog('❌ Failed to toggle video: $e');
      throw Exception('Failed to toggle video: $e');
    } finally {
      _isVideoToggling = false;
    }
  }

  Future<void> _toggleVideoTrack() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        _isVideoEnabled = !_isVideoEnabled;
        videoTrack.enabled = _isVideoEnabled;

        // Update call type if disabling video completely
        if (!_isVideoEnabled) {
          _isVideoCall = false;
        }

        _magentaLog('Video track toggled: enabled = $_isVideoEnabled');
      }
    }
  }

  // NEW: Add video track to existing audio call
  Future<void> addVideoTrack() async {
    if (!_isInCall || _isVideoToggling || _hasVideoTrack) {
      _magentaLog(
          'Cannot add video track: not in call, toggling, or already has video');
      return;
    }

    try {
      _isVideoToggling = true;
      await _addVideoTrack();
    } catch (e) {
      _magentaLog('❌ Failed to add video track: $e');
      throw Exception('Failed to add video track: $e');
    } finally {
      _isVideoToggling = false;
    }
  }

  Future<void> _addVideoTrack() async {
    try {
      _magentaLog('📹 Adding video track to existing call');

      // Request camera permission
      await _requestPermissions(true);

      // Get video stream
      final videoConstraints = {
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

      final videoStream =
          await navigator.mediaDevices.getUserMedia(videoConstraints);
      final videoTrack = videoStream.getVideoTracks().first;

      // Add video track to existing stream
      if (_localStream != null) {
        _localStream!.addTrack(videoTrack);
      } else {
        _localStream = videoStream;
      }

      // Add track to peer connection
      if (_peerConnection != null) {
        await _peerConnection!.addTrack(videoTrack, _localStream!);
        _magentaLog('✅ Video track added to peer connection');

        // Trigger renegotiation
        await _renegotiateConnection();
      }

      _isVideoEnabled = true;
      _isVideoCall = true;
      _hasVideoTrack = true;

      // Update local stream
      _localStreamController.add(_localStream!);

      _magentaLog('✅ Video track added successfully');
    } catch (e) {
      _magentaLog('❌ Failed to add video track: $e');
      throw e;
    }
  }

  Future<void> _renegotiateConnection() async {
    if (_peerConnection == null || _currentCallUserId == null) {
      return;
    }

    try {
      _magentaLog('🔄 Renegotiating connection for video track');

      // Create new offer with video
      final offerOptions = {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      };

      final offer = await _peerConnection!.createOffer(offerOptions);
      await _peerConnection!.setLocalDescription(offer);

      // Send renegotiation offer
      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'renegotiate',
        'offer': offer.toMap(),
        'callId': _currentCallId,
      });

      _magentaLog('✅ Renegotiation offer sent');
    } catch (e) {
      _magentaLog('❌ Failed to renegotiate connection: $e');
      throw e;
    }
  }

  Future<void> toggleAudio() async {
    try {
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          final audioTrack = audioTracks.first;
          _isAudioEnabled = !_isAudioEnabled;
          audioTrack.enabled = _isAudioEnabled;
          _magentaLog('Audio toggled: $_isAudioEnabled');
        }
      }
    } catch (e) {
      _magentaLog('Failed to toggle audio: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final videoTrack = videoTracks.first;
          await Helper.switchCamera(videoTrack);
          _magentaLog('Camera switched');
        }
      }
    } catch (e) {
      _magentaLog('Failed to switch camera: $e');
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

      _magentaLog(
          'Permissions granted for ${isVideo ? 'video' : 'audio'} call');
    } catch (e) {
      _magentaLog('Permission request failed: $e');
      throw Exception('Failed to get permissions: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_rtcConfiguration);
      _setupPeerConnectionCallbacks();
      _magentaLog('✅ Peer connection created successfully');
    } catch (e) {
      _magentaLog('❌ Failed to create peer connection: $e');
      throw Exception('Failed to create peer connection: $e');
    }
  }

  void _setupPeerConnectionCallbacks() {
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      _magentaLog('🎯 onTrack event received');
      _magentaLog('Track kind: ${event.track?.kind}');
      _magentaLog('Track enabled: ${event.track?.enabled}');
      _magentaLog('Streams count: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _magentaLog('Stream ID: ${stream.id}');

        // Handle different track types
        if (event.track?.kind == 'video') {
          _magentaLog('📹 Video track received');
          // Update remote stream immediately for video
          _remoteStream = stream;
          _remoteStreamController.add(_remoteStream!);
        } else if (event.track?.kind == 'audio') {
          _magentaLog('🎤 Audio track received');
          // Update remote stream for audio
          _remoteStream = stream;
          _remoteStreamController.add(_remoteStream!);
        }

        _logStreamStatus();
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _magentaLog('🔗 Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _magentaLog('✅ WebRTC Connected');
          if (!_isVideoToggling) {
            _callStateController.add(CallState.connected);
          }
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _magentaLog('❌ WebRTC Disconnected');
          if (!_isVideoToggling) {
            _callStateController.add(CallState.failed);
          }
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _magentaLog('❌ WebRTC Failed');
          _callStateController.add(CallState.failed);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _magentaLog('🔒 WebRTC Closed');
          if (!_isVideoToggling) {
            _callStateController.add(CallState.ended);
          }
          break;
        default:
          _magentaLog('🔄 WebRTC State: $state');
          break;
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      _magentaLog('🧊 ICE Connection state: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _magentaLog('✅ ICE Connected/Completed');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _magentaLog('❌ ICE Failed');
          if (!_isVideoToggling) {
            _callStateController.add(CallState.failed);
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _magentaLog('❌ ICE Disconnected');
          break;
        default:
          break;
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _magentaLog('🧊 Local ICE candidate generated');
      _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'ice-candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'callId': _currentCallId,
      });
    };
    // The following line is commented out because 'onNegotiationNeeded' is not defined for RTCPeerConnection in this package.
    // _peerConnection!.onNegotiationNeeded = () {
    //   _magentaLog('🤝 Negotiation needed - handling automatically');
    //   // Handle renegotiation if needed
    // };
  }

  void _logStreamStatus() {
    _magentaLog('📊 Stream Status Check:');
    _magentaLog('Local stream: ${_localStream != null ? 'Available' : 'NULL'}');
    _magentaLog(
        'Remote stream: ${_remoteStream != null ? 'Available' : 'NULL'}');
    _magentaLog('Has video track: $_hasVideoTrack');
    _magentaLog('Video enabled: $_isVideoEnabled');
    _magentaLog('Audio enabled: $_isAudioEnabled');

    if (_localStream != null) {
      _magentaLog(
          'Local tracks: ${_localStream!.getTracks().map((t) => '${t.kind}:${t.enabled}').join(', ')}');
    }

    if (_remoteStream != null) {
      _magentaLog(
          'Remote tracks: ${_remoteStream!.getTracks().map((t) => '${t.kind}:${t.enabled}').join(', ')}');
    }
  }

  Future<void> _getUserMedia(bool isVideo) async {
    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 44100,
          'channelCount': 1,
        },
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

      _magentaLog('🎥 Getting user media with constraints: $constraints');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localStream != null) {
        _localStreamController.add(_localStream!);
        _magentaLog(
            '✅ Local stream obtained with ${_localStream!.getTracks().length} tracks');

        // Add tracks to peer connection
        if (_peerConnection != null) {
          // Clear existing senders
          final senders = await _peerConnection!.getSenders();
          for (final sender in senders) {
            await _peerConnection!.removeTrack(sender);
          }

          // Add new tracks
          for (final track in _localStream!.getTracks()) {
            await _peerConnection!.addTrack(track, _localStream!);
            _magentaLog('✅ Track added: ${track.kind}:${track.id}');
          }
        }

        _hasVideoTrack = isVideo;
      } else {
        throw Exception('Failed to get local stream');
      }
    } catch (e) {
      _magentaLog('❌ Failed to get user media: $e');
      throw Exception('Failed to get user media: $e');
    }
  }

  Future<void> _createOfferWithTimeout() async {
    try {
      _magentaLog('📞 Creating offer...');

      final offerOptions = <String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
      };

      final offer = await _peerConnection!.createOffer(offerOptions);
      await _peerConnection!.setLocalDescription(offer);

      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'offer',
        'offer': offer.toMap(),
        'callId': _currentCallId,
        'callerId': _signalRService?.currentUserId?.toString(),
        'isVideo': _isVideoCall,
        'isMatchBased': true,
      });

      _magentaLog('✅ Offer created and sent');

      // Timeout for answer
      Timer(const Duration(seconds: 30), () async {
        if (_peerConnection != null) {
          final remoteDesc = await _peerConnection!.getRemoteDescription();
          if (remoteDesc == null) {
            _magentaLog('❌ Answer timeout - no response from remote peer');
            _callStateController.add(CallState.failed);
          }
        }
      });
    } catch (e) {
      _magentaLog('❌ Failed to create offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  Future<void> _createAnswer() async {
    try {
      _magentaLog('📞 Creating answer...');

      final answerOptions = <String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
      };

      final answer = await _peerConnection!.createAnswer(answerOptions);
      await _peerConnection!.setLocalDescription(answer);

      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'answer',
        'answer': answer.toMap(),
        'callId': _currentCallId,
      });

      _magentaLog('✅ Answer created and sent');
    } catch (e) {
      _magentaLog('❌ Failed to create answer: $e');
      throw Exception('Failed to create answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> signal) async {
    try {
      _magentaLog('🧊 Processing ICE candidate...');

      if (!signal.containsKey('candidate')) {
        _magentaLog('❌ ICE candidate signal missing "candidate" field');
        return;
      }

      final candidateData = signal['candidate'];

      if (_peerConnection == null) {
        _magentaLog('❌ Cannot add ICE candidate: peer connection is null');
        return;
      }

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc == null) {
        _magentaLog('⚠️ No remote description yet, queueing ICE candidate');
        _pendingIceCandidates.add(candidate);
        return;
      }

      await _peerConnection!.addCandidate(candidate);
      _magentaLog('✅ ICE candidate added successfully');
    } catch (e) {
      _magentaLog('❌ Error handling ICE candidate: $e');
    }
  }

  Future<void> _processPendingIceCandidates() async {
    try {
      if (_pendingIceCandidates.isNotEmpty) {
        _magentaLog(
            '📋 Processing ${_pendingIceCandidates.length} pending ICE candidates');

        for (final candidate in _pendingIceCandidates) {
          try {
            await _peerConnection!.addCandidate(candidate);
            _magentaLog('✅ Pending ICE candidate added');
          } catch (e) {
            _magentaLog('❌ Error adding pending ICE candidate: $e');
          }
        }

        _pendingIceCandidates.clear();
        _magentaLog('✅ All pending ICE candidates processed');
      }
    } catch (e) {
      _magentaLog('❌ Error processing pending ICE candidates: $e');
    }
  }

  void _handleReject() {
    _magentaLog('❌ Call rejected by remote user');
    _cleanupCall();
    _callStateController.add(CallState.rejected);
  }

  void _handleEnd() {
    _magentaLog('📞 Call ended by remote user');
    _cleanupCall();
    _callStateController.add(CallState.ended);
  }

  void _handleWebRtcSignal(String signalData) async {
    _magentaLog('📥 Raw SignalR data: $signalData');
    try {
      if (!_signalRService!.isConnected) {
        _magentaLog('❌ SignalR not connected, cannot process signal');
        _callStateController.add(CallState.failed);
        return;
      }

      final signal = jsonDecode(signalData);
      final type = signal['type'] ?? 'unknown';
      final callerId = signal['callerId'] ?? 'unknown';
      final callId = signal['callId'] ?? 'unknown';

      _magentaLog(
          'Received WebRTC signal: type=$type, from=$callerId, callId=$callId');

      switch (type) {
        case 'offer':
          await _handleOffer(signal);
          break;
        case 'answer':
          await _handleAnswer(signal);
          break;
        case 'renegotiate':
          await _handleRenegotiate(signal);
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
          _magentaLog('❓ Unknown signal type: $type');
      }
    } catch (e, stackTrace) {
      _magentaLog(
          '❌ Error parsing SignalR signal: $e\nStackTrace: $stackTrace');
      _callStateController.add(CallState.failed);
    }
  }

  Future<void> _handleRenegotiate(Map<String, dynamic> signal) async {
    try {
      _magentaLog('🔄 Handling renegotiation request');

      if (!signal.containsKey('offer')) {
        _magentaLog('❌ Renegotiate signal missing offer');
        return;
      }

      final offer = signal['offer'];
      final rtcOffer = RTCSessionDescription(offer['sdp'], offer['type']);

      if (_peerConnection == null) {
        _magentaLog('❌ Cannot handle renegotiation: peer connection is null');
        return;
      }

      // Set remote description
      await _peerConnection!.setRemoteDescription(rtcOffer);
      _magentaLog('✅ Renegotiation remote description set');

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer
      await _sendWebRtcSignal(_currentCallUserId!, {
        'type': 'renegotiate-answer',
        'answer': answer.toMap(),
        'callId': _currentCallId,
      });

      _magentaLog('✅ Renegotiation answer sent');
    } catch (e) {
      _magentaLog('❌ Error handling renegotiation: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> signal) async {
    try {
      if (!signal.containsKey('offer') ||
          !signal.containsKey('callId') ||
          !signal.containsKey('callerId')) {
        _magentaLog('❌ Invalid offer signal: missing required fields');
        return;
      }

      final offer = signal['offer'];
      final callId = signal['callId'];
      final isVideo = signal['isVideo'] ?? false;
      final callerId = signal['callerId'];
      final isMatchBased = signal['isMatchBased'] ?? false;

      if (!offer.containsKey('sdp') || !offer.containsKey('type')) {
        _magentaLog('❌ Invalid offer format: missing sdp or type');
        return;
      }

      _magentaLog(
          '📨 Received offer from $callerId, isVideo: $isVideo, isMatchBased: $isMatchBased');

      if (_isInCall) {
        _magentaLog('⚠️ Already in call, rejecting offer');
        await _sendWebRtcSignal(callerId, {
          'type': 'reject',
          'callId': callId,
        });
        return;
      }

      // Check if we already have a pending offer from the same caller
      if (_pendingOffer != null && _currentCallUserId == callerId) {
        _magentaLog(
            '⚠️ Already have pending offer from this caller, ignoring duplicate');
        return;
      }

      _pendingOffer = RTCSessionDescription(offer['sdp'], offer['type']);
      _currentCallId = callId;
      _currentCallUserId = callerId;
      _isIncomingCall = true;

      // Only emit incoming call event if it's not match-based
      if (!isMatchBased) {
        _incomingCallController.add(IncomingCall(
          callerId: callerId,
          callId: callId,
          isVideo: isVideo,
        ));
      } else {
        // For match-based calls, automatically accept the call
        _magentaLog('🤝 Auto-accepting match-based call from $callerId');
        // Small delay to ensure everything is ready
        await Future.delayed(const Duration(milliseconds: 200));
        await acceptIncomingCall(callerId, isVideo);
      }

      _magentaLog('✅ Incoming call offer processed');
    } catch (e) {
      _magentaLog('❌ Error handling offer: $e');
      _callStateController.add(CallState.failed);
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> signal) async {
    try {
      _magentaLog('📞 Answer received, processing...');

      if (!signal.containsKey('answer')) {
        _magentaLog('❌ Answer signal missing "answer" field');
        return;
      }

      final answer = signal['answer'];
      final rtcAnswer = RTCSessionDescription(answer['sdp'], answer['type']);

      if (_peerConnection == null) {
        _magentaLog('❌ Cannot process answer: peer connection is null');
        return;
      }

      await _peerConnection!.setRemoteDescription(rtcAnswer);
      _magentaLog('✅ Remote description set successfully');

      // Process any pending ICE candidates
      await _processPendingIceCandidates();

      _logStreamStatus();

      // Emit connected state after answer is processed
      await Future.delayed(const Duration(milliseconds: 200));
      _callStateController.add(CallState.connected);
      _magentaLog('✅ Call connected state emitted');
    } catch (e) {
      _magentaLog('❌ Error handling answer: $e');
      _callStateController.add(CallState.failed);
    }
  }

  Future<void> _processPendingOffer() async {
    try {
      if (_pendingOffer == null) {
        _magentaLog('❌ _processPendingOffer called but _pendingOffer is null!');
        throw Exception('No pending offer to process');
      }
      _magentaLog(
          '📞 Processing pending offer: type= [36m${_pendingOffer!.type} [0m, sdp length=${_pendingOffer?.sdp?.length ?? 0}');
      await _peerConnection!.setRemoteDescription(_pendingOffer!);
      _magentaLog('✅ setRemoteDescription completed');
      _magentaLog(
          'PeerConnection signalingState after setRemoteDescription:  [36m${_peerConnection!.signalingState} [0m');
      await _processPendingIceCandidates();
      _pendingOffer = null;
      _magentaLog('✅ Pending offer processed');
    } catch (e) {
      _magentaLog('❌ Error processing pending offer: $e');
      throw e;
    }
  }

  Future<void> _sendWebRtcSignal(
      String targetUserId, Map<String, dynamic> signal) async {
    try {
      if (_signalRService == null) {
        throw Exception('SignalR service not initialized');
      }

      if (!_signalRService!.isConnected) {
        _magentaLog('SignalR not connected, attempting to reconnect...');
        if (_signalRService!.currentUserId != null &&
            _signalRService!.accessToken != null) {
          await _signalRService!.initialize(
            userId: _signalRService!.currentUserId!,
            accessToken: _signalRService!.accessToken!,
            enableAutoReconnect: true,
          );
          const maxWaitTime = Duration(seconds: 5);
          final startTime = DateTime.now();
          while (!_signalRService!.isConnected &&
              DateTime.now().difference(startTime) < maxWaitTime) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } else {
          throw Exception(
              'Cannot reconnect SignalR: missing userId or accessToken');
        }

        if (!_signalRService!.isConnected) {
          throw Exception('SignalR connection failed after retry');
        }
      }

      final signalData = jsonEncode(signal);
      await _signalRService!.sendWebRtcSignal(
        targetUserId: targetUserId,
        signalData: signalData,
      );

      _magentaLog(
          'Signal sent successfully: ${signal['type']} to $targetUserId');
    } catch (e, stackTrace) {
      _magentaLog('Failed to send WebRTC signal: $e\nStackTrace: $stackTrace');
      throw Exception('Failed to send signal: $e');
    }
  }

  Future<void> _cleanupCall() async {
    try {
      _magentaLog('🧹 Cleaning up call...');

      // Stop all tracks
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Clear pending ICE candidates
      _pendingIceCandidates.clear();

      // Reset state
      _isInCall = false;
      _isVideoCall = false;
      _isVideoEnabled = true;
      _isAudioEnabled = true;
      _currentCallUserId = null;
      _currentCallId = null;
      _isIncomingCall = false;
      _pendingOffer = null;

      _magentaLog('✅ Call cleanup completed');
    } catch (e) {
      _magentaLog('❌ Error during cleanup: $e');
    }
  }

  bool get isInCall => _isInCall;
  bool get isVideoCall => _isVideoCall;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  String? get currentCallUserId => _currentCallUserId;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  void dispose() {
    _cleanupCall();
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
