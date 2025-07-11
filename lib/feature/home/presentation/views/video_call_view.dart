import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:e_learning_app/feature/home/data/call_cubit.dart';

class VideoCallPage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const VideoCallPage({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
  }) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<CallCubit>(),
      child: BlocListener<CallCubit, CallCubitState>(
        listener: (context, state) {
          if (state is CallEnded) {
            Navigator.of(context).pop();
          } else if (state is CallFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pop();
          }
        },
        child: BlocBuilder<CallCubit, CallCubitState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(
                  children: [
                    // Status Bar
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    ),

                    // Header
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.white,
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
                                    color: Colors.black,
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
                    ),

                    // Video Container
                    Expanded(
                      child: Container(
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
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.stay_current_landscape,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Control Buttons
                    Container(
                      padding: EdgeInsets.all(20),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: state is CallConnected && !state.isVideoOff
                                ? Icons.videocam
                                : Icons.videocam_off,
                            onTap: () {
                              if (state is CallConnected) {
                                context.read<CallCubit>().toggleVideo();
                              }
                            },
                          ),
                          _buildControlButton(
                            icon: state is CallConnected && !state.isMuted
                                ? Icons.mic
                                : Icons.mic_off,
                            onTap: () {
                              if (state is CallConnected) {
                                context.read<CallCubit>().toggleMute();
                              }
                            },
                          ),
                          _buildControlButton(
                            icon: state is CallConnected && state.isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_down,
                            onTap: () {
                              if (state is CallConnected) {
                                context.read<CallCubit>().toggleSpeaker();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Bottom Buttons
                    Container(
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
      // Update video streams
      final callCubit = context.read<CallCubit>();
      if (callCubit.localStream != null) {
        _localRenderer.srcObject = callCubit.localStream;
      }
      if (callCubit.remoteStream != null) {
        _remoteRenderer.srcObject = callCubit.remoteStream;
      }

      return Column(
        children: [
          // Main participant (top half)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),

          // Self view (bottom half)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              child: RTCVideoView(
                _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
        ],
      );
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
  }
}
