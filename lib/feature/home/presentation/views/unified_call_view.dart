import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:e_learning_app/feature/home/data/call_cubit.dart';
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

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.isVideoCall;
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

  Future<void> _toggleVideoModeWithRenegotiation() async {
    print('Video toggle (renegotiation) called - current mode: $_isVideoMode');
    final callCubit = context.read<CallCubit>();
    final currentState = callCubit.state;
    if (currentState is CallConnected || currentState is CallConnecting) {
      await callCubit.toggleVideoModeWithRenegotiation();
      setState(() {
        _isVideoMode = !_isVideoMode;
      });
      print('Video mode toggled (renegotiation) to: $_isVideoMode');
    } else {
      print(
          'Cannot toggle video (renegotiation), invalid state: ${currentState.runtimeType}');
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
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            if (state is CallFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else if (state is CallConnected) {
            setState(() {
              _isVideoMode = state.isVideo && !state.isVideoOff;
            });
            _updateVideoStreams();
          } else if (state is CallConnecting) {
            _updateVideoStreams();
          }
        },
        child: BlocBuilder<CallCubit, CallCubitState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: _isVideoMode ? Colors.black : Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    // Status Bar (only for video mode)
                    if (_isVideoMode) _buildStatusBar(),

                    // Header
                    _buildHeader(state),

                    // Main Content Area
                    Expanded(
                      child: _isVideoMode
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

    const green = '\x1B[32m';
    const reset = '\x1B[0m';
    print('${green}[DEBUG] Updating video streams...${reset}');
    print('${green}[DEBUG] Local stream: ${callCubit.localStream}${reset}');
    if (callCubit.localStream != null) {
      print(
          '${green}[DEBUG] Local stream tracks: ${callCubit.localStream!.getTracks().map((t) => t.id).toList()}${reset}');
    }
    // Debug prints for remote stream
    print('${green}[DEBUG] Remote stream: ${callCubit.remoteStream}${reset}');
    if (callCubit.remoteStream != null) {
      print(
          '${green}[DEBUG] Remote stream tracks: ${callCubit.remoteStream!.getTracks().map((t) => t.id).toList()}${reset}');
    }

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
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 18),
              SizedBox(width: 4),
              Icon(Icons.wifi, size: 18),
              SizedBox(width: 4),
              Icon(Icons.battery_full, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CallCubitState state) {
    return Container(
      padding: EdgeInsets.all(16),
      color: _isVideoMode ? Colors.white : Colors.transparent,
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
                    color: _isVideoMode ? Colors.black : Colors.black,
                  ),
                ),
                if (state is CallConnected)
                  Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          if (_isVideoMode)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.brown,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent(CallCubitState state) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
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

              const SizedBox(height: 10),

              // Call Duration
              Text(
                _callDuration,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
        if (state is CallConnected && _isInitialized)
          Positioned(
            left: -100,
            top: -100,
            child: Container(
              width: 50,
              height: 50,
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoContent(CallCubitState state) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main Video Area
          Container(
            width: double.infinity,
            height: double.infinity,
            child: _buildVideoLayout(state),
          ),

          // Layout Toggle Button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                // Toggle layout if needed
                context.read<CallCubit>().switchCamera();
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.switch_camera,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLayout(CallCubitState state) {
    if (!_isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state is CallConnected) {
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: _hasRemoteStream
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Waiting for ${widget.targetUserName}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              child: _hasLocalStream
                  ? RTCVideoView(
                      _localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey[700],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white30,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'You',
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
          ),
        ],
      );
    } else {
      // Show placeholder when not connected
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange[300]!, Colors.brown[400]!],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Connecting...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              child: _hasLocalStream
                  ? RTCVideoView(
                      _localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue[300]!, Colors.blue[600]!],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white30,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'You',
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
          ),
        ],
      );
    }
  }

  Widget _buildControlButtons(CallCubitState state) {
    bool isVideoEnabled = false;
    if (state is CallConnected) {
      isVideoEnabled = state.isVideo && !state.isVideoOff;
    }

    if (_isVideoMode) {
      return Container(
        padding: EdgeInsets.all(20),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onTap: () {
                print('Video toggle button pressed (video mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  _toggleVideoModeWithRenegotiation();
                } else {
                  print(
                      'Cannot toggle video (video mode), state is: ${state.runtimeType}');
                }
              },
            ),
            _buildControlButton(
              icon: state is CallConnected && !state.isMuted
                  ? Icons.mic
                  : Icons.mic_off,
              onTap: () {
                print('Mute button pressed (video mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  context.read<CallCubit>().toggleMute();
                } else {
                  print(
                      'Cannot toggle mute (video mode), state is: ${state.runtimeType}');
                }
              },
            ),
            _buildControlButton(
              icon: state is CallConnected && state.isSpeakerOn
                  ? Icons.volume_up
                  : Icons.volume_down,
              onTap: () {
                print('Speaker button pressed (video mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  context.read<CallCubit>().toggleSpeaker();
                } else {
                  print(
                      'Cannot toggle speaker (video mode), state is: ${state.runtimeType}');
                }
              },
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Speaker Button
            _buildControlButton(
              icon: state is CallConnected && state.isSpeakerOn
                  ? Icons.volume_up
                  : Icons.volume_down,
              onTap: () {
                print('Speaker button pressed (voice mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  context.read<CallCubit>().toggleSpeaker();
                } else {
                  print(
                      'Cannot toggle speaker (voice mode), state is: ${state.runtimeType}');
                }
              },
            ),

            // Mute Button
            _buildControlButton(
              icon: state is CallConnected && !state.isMuted
                  ? Icons.mic
                  : Icons.mic_off,
              onTap: () {
                print('Mute button pressed (voice mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  context.read<CallCubit>().toggleMute();
                } else {
                  print(
                      'Cannot toggle mute (voice mode), state is: ${state.runtimeType}');
                }
              },
            ),

            // Video Toggle Button
            _buildControlButton(
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onTap: () {
                print('Video toggle button pressed (voice mode)!');
                if (state is CallConnected || state is CallConnecting) {
                  _toggleVideoModeWithRenegotiation();
                } else {
                  print(
                      'Cannot toggle video (voice mode), state is: ${state.runtimeType}');
                }
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBottomButtons() {
    if (_isVideoMode) {
      return Container(
        padding: EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  context.read<CallCubit>().endCall();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 16),
                    SizedBox(width: 8),
                    Text('End Call'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(20.0),
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
                    children: const [
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
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    if (_isVideoMode) {
      return GestureDetector(
        onTap: () {
          print('Button tapped!');
          onTap();
        },
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 24,
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          print('Button tapped (voice mode)!');
          onTap();
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 28,
            color: Colors.grey[600],
          ),
        ),
      );
    }
  }
}
