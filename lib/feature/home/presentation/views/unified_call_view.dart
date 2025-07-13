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

class _UnifiedCallPageState extends State<UnifiedCallPage>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _buttonController;

  // UI state (independent of Cubit state)
  bool _isInitialized = false;
  String _callDuration = '00:00';
  Timer? _durationTimer;
  DateTime? _callStartTime;
  bool _hasPopped = false;

  // Local UI state for smooth interactions
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  bool _speakerEnabled = false;
  bool _showVideoUI = false;

  // Smooth transition states
  bool _isVideoToggling = false;
  bool _isAudioToggling = false;
  bool _isSpeakerToggling = false;

  // Stream states
  bool _hasLocalStream = false;
  bool _hasRemoteStream = false;

  // Prevent multiple operations
  bool _isOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCallState();
    _initializeRenderers();
    _startCallTimer();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeController.forward();
    _scaleController.forward();
    _buttonController.forward();
  }

  void _initializeCallState() {
    _showVideoUI = widget.isVideoCall;
    _localVideoEnabled = widget.isVideoCall;
    _localAudioEnabled = true;
    _speakerEnabled = false;
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Update streams after initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateVideoStreams();
        });
      }
    } catch (e) {
      print('Error initializing renderers: $e');
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _buttonController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_callStartTime != null && mounted) {
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
    if (!mounted) return;

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

  // Smooth video toggle without rebuilding the entire page
  Future<void> _toggleVideoMode() async {
    if (_isOperationInProgress) return;

    setState(() {
      _isVideoToggling = true;
      _isOperationInProgress = true;
    });

    try {
      // Animate button press
      await _buttonController.reverse();
      _buttonController.forward();

      final callCubit = context.read<CallCubit>();

      if (_localVideoEnabled) {
        // Turn off video
        await callCubit.toggleVideo();

        // Update local state immediately for smooth UI
        setState(() {
          _localVideoEnabled = false;
          // Only hide video UI if both local and remote video are off
          if (!_hasRemoteStream) {
            _showVideoUI = false;
          }
        });
      } else {
        // Turn on video
        await callCubit.toggleVideo();

        // Update local state immediately for smooth UI
        setState(() {
          _localVideoEnabled = true;
          _showVideoUI = true;
        });
      }

      print('Video mode toggled to: $_localVideoEnabled');
    } catch (e) {
      print('Error toggling video: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isVideoToggling = false;
          _isOperationInProgress = false;
        });
      }
    }
  }

  // Smooth audio toggle
  Future<void> _toggleAudio() async {
    if (_isOperationInProgress) return;

    setState(() {
      _isAudioToggling = true;
      _isOperationInProgress = true;
    });

    try {
      // Animate button press
      await _buttonController.reverse();
      _buttonController.forward();

      // Update UI immediately
      setState(() {
        _localAudioEnabled = !_localAudioEnabled;
      });

      // Call the cubit method
      await context.read<CallCubit>().toggleMute();

      print('Audio toggled to: $_localAudioEnabled');
    } catch (e) {
      print('Error toggling audio: $e');
      // Revert on error
      setState(() {
        _localAudioEnabled = !_localAudioEnabled;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAudioToggling = false;
          _isOperationInProgress = false;
        });
      }
    }
  }

  // Smooth speaker toggle
  Future<void> _toggleSpeaker() async {
    if (_isOperationInProgress) return;

    setState(() {
      _isSpeakerToggling = true;
      _isOperationInProgress = true;
    });

    try {
      // Animate button press
      await _buttonController.reverse();
      _buttonController.forward();

      // Update UI immediately
      setState(() {
        _speakerEnabled = !_speakerEnabled;
      });

      // Call the cubit method
      await context.read<CallCubit>().toggleSpeaker();

      print('Speaker toggled to: $_speakerEnabled');
    } catch (e) {
      print('Error toggling speaker: $e');
      // Revert on error
      setState(() {
        _speakerEnabled = !_speakerEnabled;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSpeakerToggling = false;
          _isOperationInProgress = false;
        });
      }
    }
  }

  void _updateVideoStreams() {
    if (!_isInitialized || !mounted) return;

    final callCubit = context.read<CallCubit>();

    // Update local stream
    if (callCubit.localStream != null) {
      if (_localRenderer.srcObject != callCubit.localStream) {
        _localRenderer.srcObject = callCubit.localStream;
        if (mounted) {
          setState(() {
            _hasLocalStream = true;
          });
        }
      }
    } else {
      if (_hasLocalStream) {
        _localRenderer.srcObject = null;
        if (mounted) {
          setState(() {
            _hasLocalStream = false;
          });
        }
      }
    }

    // Update remote stream
    if (callCubit.remoteStream != null) {
      if (_remoteRenderer.srcObject != callCubit.remoteStream) {
        _remoteRenderer.srcObject = callCubit.remoteStream;
        if (mounted) {
          setState(() {
            _hasRemoteStream = true;
            // Show video UI if remote stream is available
            if (!_showVideoUI) {
              _showVideoUI = true;
            }
          });
        }
      }
    } else {
      if (_hasRemoteStream) {
        _remoteRenderer.srcObject = null;
        if (mounted) {
          setState(() {
            _hasRemoteStream = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<CallCubit>(),
      child: BlocListener<CallCubit, CallCubitState>(
        listener: (context, state) {
          // Handle call end states
          if ((state is CallEnded || state is CallFailed) && !_hasPopped) {
            _hasPopped = true;

            if (state is CallEnded && mounted) {
              // Small delay to ensure smooth transition
              Future.delayed(Duration(milliseconds: 300), () {
                if (mounted) {
                  _showCallFeedbackDialog();
                }
              });
            } else if (state is CallFailed && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );

              Future.delayed(Duration(milliseconds: 300), () {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }
          }

          // Sync with cubit state when needed (without rebuilding)
          if (state is CallConnected && mounted) {
            _updateVideoStreams();

            // Only update if there's a significant change
            if (_localAudioEnabled != !state.isMuted) {
              setState(() {
                _localAudioEnabled = !state.isMuted;
              });
            }

            if (_speakerEnabled != state.isSpeakerOn) {
              setState(() {
                _speakerEnabled = state.isSpeakerOn;
              });
            }
          }
        },
        child: BlocBuilder<CallCubit, CallCubitState>(
          buildWhen: (previous, current) {
            // Only rebuild for significant state changes
            if (current is CallConnecting && previous is CallInitial)
              return true;
            if (current is CallConnected && previous is CallConnecting)
              return true;
            if (current is CallEnded || current is CallFailed) return true;
            return false;
          },
          builder: (context, state) {
            return AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: Scaffold(
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
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: _showVideoUI
                                  ? _buildVideoContent(state)
                                  : _buildVoiceContent(state),
                            ),
                          ),

                          // Control Buttons
                          _buildControlButtons(state),

                          // Bottom Action Buttons
                          _buildBottomButtons(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
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
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        children: [
          Hero(
            tag: 'user_avatar',
            child: CircleAvatar(
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
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        state is CallConnected ? Colors.green : Colors.orange,
                  ),
                  child: Text(
                    state is CallConnected ? 'Connected' : 'Connecting...',
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
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleController,
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Profile Avatar with pulse animation
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4C2A1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
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
                        _localAudioEnabled ? Icons.call : Icons.call_end,
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
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        state is CallConnected ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w400,
                  ),
                  child: Text(
                    state is CallConnected ? 'Connected' : 'Connecting...',
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(CallCubitState state) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main Video Area
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_hasRemoteStream),
              width: double.infinity,
              height: double.infinity,
              child: _buildMainVideoView(state),
            ),
          ),

          // Picture-in-Picture with smooth transitions
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            top: 80,
            right: _localVideoEnabled && _hasLocalStream ? 16 : -140,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 200),
              opacity: _localVideoEnabled && _hasLocalStream ? 1.0 : 0.0,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _hasLocalStream
                      ? RTCVideoView(
                          _localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(color: Colors.grey[800]),
                ),
              ),
            ),
          ),

          // Camera Switch Button
          Positioned(
            top: 80,
            left: 16,
            child: AnimatedScale(
              scale: _localVideoEnabled ? 1.0 : 0.0,
              duration: Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => context.read<CallCubit>().switchCamera(),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoView(CallCubitState state) {
    if (_hasRemoteStream) {
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
              Hero(
                tag: 'user_avatar_large',
                child: CircleAvatar(
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
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Audio/Mute Button
          _buildControlButton(
            icon: _localAudioEnabled ? Icons.mic : Icons.mic_off,
            isActive: _localAudioEnabled,
            isLoading: _isAudioToggling,
            onTap: _toggleAudio,
          ),

          // Video Toggle Button
          _buildControlButton(
            icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _localVideoEnabled,
            isLoading: _isVideoToggling,
            onTap: _toggleVideoMode,
          ),

          // Speaker Button
          _buildControlButton(
            icon: _speakerEnabled ? Icons.volume_up : Icons.volume_down,
            isActive: _speakerEnabled,
            isLoading: _isSpeakerToggling,
            onTap: _toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20),
      color: _showVideoUI ? Colors.black87 : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
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
    bool isLoading = false,
  }) {
    return AnimatedBuilder(
      animation: _buttonController,
      builder: (context, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
          ),
          child: GestureDetector(
            onTap: isLoading ? null : onTap,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isActive
                    ? (_showVideoUI ? Colors.white24 : Colors.grey[200])
                    : Colors.red.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _showVideoUI ? Colors.white : Colors.grey[600]!,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 28,
                      color: isActive
                          ? (_showVideoUI ? Colors.white : Colors.grey[600])
                          : Colors.white,
                    ),
            ),
          ),
        );
      },
    );
  }
}
