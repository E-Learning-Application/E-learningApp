import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:e_learning_app/feature/home/data/call_cubit.dart';
import 'package:e_learning_app/feature/feedback/presentation/widgets/call_feedback_dialog.dart';
import 'dart:async';

class UnifiedCallPage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final bool isVideoCall;

  const UnifiedCallPage({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
    this.isVideoCall = false,
  }) : super(key: key);

  @override
  _UnifiedCallPageState createState() => _UnifiedCallPageState();
}

class _UnifiedCallPageState extends State<UnifiedCallPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isInitialized = false;
  String _callDuration = '00:00';
  Timer? _durationTimer;
  DateTime? _callStartTime;
  bool _isVideoMode = false;
  bool _hasLocalStream = false;
  bool _hasRemoteStream = false;
  bool _hasPopped = false;
  bool _showVideoUI = false; // Controls UI layout
  bool _localVideoEnabled = true; // Local video state
  bool _remoteVideoEnabled = true; // Remote video state
  bool _isRenegotiating = false; // Add this flag

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.isVideoCall;
    _showVideoUI = widget.isVideoCall;
    _startCallTimer();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      setState(() {
        _isInitialized = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateVideoStreams();
      });
    } catch (e) {
      print('Error initializing renderers: $e');
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _callDuration = '$minutes:$seconds';
        });
      }
    });
  }

  void _showCallFeedbackDialog() {
    // Don't show feedback during renegotiation
    if (_isRenegotiating) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CallFeedbackDialog(
        targetUserName: widget.targetUserName,
        callDuration: _callDuration,
        isVideoCall: _showVideoUI,
      ),
    );
  }

  Future<void> _toggleVideoMode() async {
    print('Video toggle called - current mode: $_isVideoMode');
    final callCubit = context.read<CallCubit>();
    final currentState = callCubit.state;

    if (currentState is CallConnected || currentState is CallConnecting) {
      if (_isVideoMode) {
        // Currently in video mode, turning off video (but staying in video call)
        await callCubit.toggleVideo();
        setState(() {
          _localVideoEnabled = false;
          if (!_remoteVideoEnabled) {
            _showVideoUI = false; // Switch to voice UI if both videos are off
          }
        });
      } else {
        // Currently in voice mode, need to switch to video call
        // Set renegotiation flag to prevent feedback dialog
        setState(() {
          _isRenegotiating = true;
        });

        try {
          await callCubit.toggleVideoModeWithRenegotiation();
          setState(() {
            _localVideoEnabled = true;
            _showVideoUI = true; // Switch to video UI
          });
        } finally {
          // Reset renegotiation flag after completion
          setState(() {
            _isRenegotiating = false;
          });
        }
      }

      setState(() {
        _isVideoMode = !_isVideoMode;
      });

      print('Video mode toggled to: $_isVideoMode');
    } else {
      print('Cannot toggle video, invalid state: ${currentState.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<CallCubit>(),
      child: BlocListener<CallCubit, CallCubitState>(
        listener: (context, state) {
          if ((state is CallEnded || state is CallFailed) && !_hasPopped) {
            _hasPopped = true;

            // Only show feedback dialog if it's a real call end, not renegotiation
            if (state is CallEnded && mounted && !_isRenegotiating) {
              _showCallFeedbackDialog();
            } else if (!_isRenegotiating) {
              // Only pop if not renegotiating
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }

            if (state is CallFailed && !_isRenegotiating) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else if (state is CallConnected) {
            // Reset _hasPopped when reconnected (after renegotiation)
            setState(() {
              _hasPopped = false;
              _isVideoMode = state.isVideo && !state.isVideoOff;
              _localVideoEnabled = state.isVideo && !state.isVideoOff;
              // Update UI based on video availability
              _showVideoUI = _localVideoEnabled || _remoteVideoEnabled;
            });
            _updateVideoStreams();
          } else if (state is CallConnecting) {
            // Reset _hasPopped when connecting (during renegotiation)
            setState(() {
              _hasPopped = false;
            });
            _updateVideoStreams();
          }
        },
        child: BlocBuilder<CallCubit, CallCubitState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: _showVideoUI ? Colors.black : Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    // Status Bar (only for video UI)
                    if (_showVideoUI) _buildStatusBar(),

                    // Header
                    _buildHeader(state),

                    // Main Content Area
                    Expanded(
                      child: _showVideoUI
                          ? _buildVideoContent(state)
                          : _buildVoiceContent(state),
                    ),

                    // Control Buttons
                    _buildControlButtons(state),

                    // Bottom Action Buttons
                    _buildBottomButtons(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateVideoStreams() {
    if (!_isInitialized) return;

    final callCubit = context.read<CallCubit>();

    print('[DEBUG] Updating video streams...');
    print('[DEBUG] Local stream: ${callCubit.localStream}');
    print('[DEBUG] Remote stream: ${callCubit.remoteStream}');

    if (callCubit.localStream != null) {
      if (_localRenderer.srcObject != callCubit.localStream) {
        _localRenderer.srcObject = callCubit.localStream;
        print('Local stream updated');
        setState(() {
          _hasLocalStream = true;
        });
      }
    } else {
      if (_hasLocalStream) {
        _localRenderer.srcObject = null;
        setState(() {
          _hasLocalStream = false;
        });
      }
    }

    if (callCubit.remoteStream != null) {
      if (_remoteRenderer.srcObject != callCubit.remoteStream) {
        _remoteRenderer.srcObject = callCubit.remoteStream;
        print('Remote stream updated');
        setState(() {
          _hasRemoteStream = true;
        });
      }
    } else {
      if (_hasRemoteStream) {
        _remoteRenderer.srcObject = null;
        setState(() {
          _hasRemoteStream = false;
        });
      }
    }
  }

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Icon(Icons.wifi, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Icon(Icons.battery_full, size: 18, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CallCubitState state) {
    return Container(
      padding: EdgeInsets.all(16),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange,
            child: Text(
              widget.targetUserName.isNotEmpty
                  ? widget.targetUserName[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetUserName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _showVideoUI ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  state is CallConnected ? 'Connected' : 'Connecting...',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        state is CallConnected ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _callDuration,
            style: TextStyle(
              fontSize: 14,
              color: _showVideoUI ? Colors.white70 : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent(CallCubitState state) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Profile Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF4C2A1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  state is CallConnected ? Icons.call : Icons.call_end,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Name
          Text(
            widget.targetUserName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 10),

          // Call Status
          Text(
            state is CallConnected ? 'Connected' : 'Connecting...',
            style: TextStyle(
              fontSize: 16,
              color: state is CallConnected ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w400,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildVideoContent(CallCubitState state) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main Video Area - Remote or Local
          Container(
            width: double.infinity,
            height: double.infinity,
            child: _buildMainVideoView(state),
          ),

          // Picture-in-Picture (PiP) for local video
          if (_localVideoEnabled && _hasLocalStream)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Camera Switch Button
          Positioned(
            top: 80,
            left: 16,
            child: GestureDetector(
              onTap: () => context.read<CallCubit>().switchCamera(),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoView(CallCubitState state) {
    // Show remote video if available, otherwise show local video or placeholder
    if (_remoteVideoEnabled && _hasRemoteStream) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else if (_localVideoEnabled && _hasLocalStream) {
      return RTCVideoView(
        _localRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.orange,
                child: Text(
                  widget.targetUserName.isNotEmpty
                      ? widget.targetUserName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                widget.targetUserName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                state is CallConnected ? 'Camera is off' : 'Connecting...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildControlButtons(CallCubitState state) {
    bool isAudioMuted = false;
    bool isSpeakerOn = false;

    if (state is CallConnected) {
      isAudioMuted = state.isMuted;
      isSpeakerOn = state.isSpeakerOn;
    }

    return Container(
      padding: EdgeInsets.all(20),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Audio/Mute Button
          _buildControlButton(
            icon: isAudioMuted ? Icons.mic_off : Icons.mic,
            isActive: !isAudioMuted,
            onTap: () {
              print('Mute button pressed!');
              if (state is CallConnected || state is CallConnecting) {
                context.read<CallCubit>().toggleMute();
              }
            },
          ),

          // Video Toggle Button
          _buildControlButton(
            icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _localVideoEnabled,
            onTap: () {
              print('Video toggle button pressed!');
              if (state is CallConnected || state is CallConnecting) {
                _toggleVideoMode();
              }
            },
          ),

          // Speaker Button
          _buildControlButton(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            isActive: isSpeakerOn,
            onTap: () {
              print('Speaker button pressed!');
              if (state is CallConnected || state is CallConnecting) {
                context.read<CallCubit>().toggleSpeaker();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextButton(
                onPressed: () {
                  context.read<CallCubit>().endCall();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'End Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive
              ? (_showVideoUI ? Colors.white24 : Colors.grey[200])
              : Colors.red.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isActive
              ? (_showVideoUI ? Colors.white : Colors.grey[600])
              : Colors.white,
        ),
      ),
    );
  }
}
