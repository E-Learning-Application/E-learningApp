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
    ],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'enableDscp': true,
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
    try {
      if (_isInCall) {
        throw Exception('Already in a call');
      }
      _isVideoCall = false;
      _isVideoEnabled = false;
      _isAudioEnabled = true;
      _currentCallUserId = targetUserId;
      _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
      _isIncomingCall = false;

      _magentaLog('Starting audio call to $targetUserId');
      _callStateController.add(CallState.connecting);

      await _requestPermissions(false);
      await _createPeerConnection();
      await _getUserMedia(false);
      await _createOfferWithTimeout();

      _isInCall = true;
      _magentaLog('Call initiated to user: $targetUserId');
    } catch (e, stackTrace) {
      _magentaLog('Failed to initiate call: $e\nStackTrace: $stackTrace');
      _callStateController.add(CallState.failed);
      await _cleanupCall();
      throw Exception('Failed to start call: $e');
    }
  }

  Future<void> _initiateCall(String targetUserId, bool isVideo) async {
    try {
      if (_isInCall) {
        throw Exception('Already in a call');
      }

      _isVideoCall = isVideo;
      _isVideoEnabled = isVideo;
      _isAudioEnabled = true;
      _currentCallUserId = targetUserId;
      _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
      _isIncomingCall = false;

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

      _magentaLog(
          'Accepting ${isVideo ? 'video' : 'audio'} call from $callerId');
      _callStateController.add(CallState.connecting);

      await _requestPermissions(isVideo);
      await _createPeerConnection();
      await _getUserMedia(isVideo);
      await _processPendingOffer();
      if (_peerConnection != null) {
        _magentaLog(
            'PeerConnection state after setRemoteDescription: ${_peerConnection!.signalingState}');
      }
      await _createAnswer();

      _isInCall = true;
      _magentaLog('Incoming call accepted from user: $callerId');
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

  Future<void> toggleVideo() async {
    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final videoTrack = videoTracks.first;
          _isVideoEnabled = !_isVideoEnabled;
          videoTrack.enabled = _isVideoEnabled;
          _magentaLog('Video toggled: $_isVideoEnabled');
        }
      }
    } catch (e) {
      _magentaLog('Failed to toggle video: $e');
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
      _magentaLog('Track id: ${event.track?.id}');
      _magentaLog('Track enabled: ${event.track?.enabled}');
      _magentaLog('Streams count: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _magentaLog('Stream ID: ${stream.id}');
        _magentaLog(
            'Stream tracks: ${stream.getTracks().map((t) => '${t.kind}:${t.id}').join(', ')}');

        // Set remote stream immediately
        _remoteStream = stream;
        _remoteStreamController.add(_remoteStream!);
        _magentaLog('✅ Remote stream set successfully');

        // Force update the UI
        _logStreamStatus();
      } else {
        _magentaLog('⚠️ No streams in onTrack event');
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _magentaLog('🔗 Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _magentaLog('✅ WebRTC Connected');
          _callStateController.add(CallState.connected);
          _logStreamStatus();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _magentaLog('❌ WebRTC Disconnected');
          _callStateController.add(CallState.failed);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _magentaLog('❌ WebRTC Failed');
          _callStateController.add(CallState.failed);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _magentaLog('🔒 WebRTC Closed');
          _callStateController.add(CallState.ended);
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
          _logStreamStatus();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _magentaLog('❌ ICE Failed');
          _callStateController.add(CallState.failed);
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

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _magentaLog('📡 Data channel received: ${channel.label}');
    };
  }

  void _logStreamStatus() {
    _magentaLog('📊 Stream Status Check:');
    _magentaLog('Local stream: ${_localStream != null ? 'Available' : 'NULL'}');
    _magentaLog(
        'Remote stream: ${_remoteStream != null ? 'Available' : 'NULL'}');

    if (_localStream != null) {
      _magentaLog(
          'Local tracks: ${_localStream!.getTracks().map((t) => '${t.kind}:${t.id}').join(', ')}');
    }

    if (_remoteStream != null) {
      _magentaLog(
          'Remote tracks: ${_remoteStream!.getTracks().map((t) => '${t.kind}:${t.id}').join(', ')}');
    }

    if (_peerConnection != null) {
      _magentaLog('Peer connection state: ${_peerConnection!.connectionState}');
      _magentaLog(
          'ICE connection state: ${_peerConnection!.iceConnectionState}');
    }
  }

  Future<void> _getUserMedia(bool isVideo) async {
    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
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
          // Only clear senders if negotiation is needed (e.g., for offerer)
          // For callee, adding tracks before remote description is fine
          final senders = await _peerConnection!.getSenders();
          for (final sender in senders) {
            await _peerConnection!.removeTrack(sender);
          }

          for (final track in _localStream!.getTracks()) {
            await _peerConnection!.addTrack(track, _localStream!);
            _magentaLog('✅ Track added: ${track.kind}:${track.id}');
          }
        }
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
        'callerId':
            _signalRService?.currentUserId?.toString(), // <-- Added callerId
        'isVideo': _isVideoCall,
      });

      _magentaLog('✅ Offer created and sent');
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

      if (!offer.containsKey('sdp') || !offer.containsKey('type')) {
        _magentaLog('❌ Invalid offer format: missing sdp or type');
        return;
      }

      _magentaLog('📨 Received offer from $callerId, isVideo: $isVideo');

      if (_isInCall) {
        _magentaLog('⚠️ Already in call, rejecting offer');
        await _sendWebRtcSignal(callerId, {
          'type': 'reject',
          'callId': callId,
        });
        return;
      }

      _pendingOffer = RTCSessionDescription(offer['sdp'], offer['type']);
      _currentCallId = callId;
      _currentCallUserId = callerId;
      _isIncomingCall = true;

      _incomingCallController.add(IncomingCall(
        callerId: callerId,
        callId: callId,
        isVideo: isVideo,
      ));

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
