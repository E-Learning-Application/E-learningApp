import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_learning_app/feature/home/data/call_cubit.dart';
import 'dart:async';

class VoiceCallPage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const VoiceCallPage({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
  }) : super(key: key);

  @override
  _VoiceCallPageState createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  String _callDuration = '00:00';
  Timer? _durationTimer;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _startCallTimer();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
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
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: const SizedBox(), // Remove back button
                title: Text(
                  'Voice Call',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
              ),
              body: Padding(
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
                        color:
                            const Color(0xFFF4C2A1), // Light orange background
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2), // Blue color
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state is CallConnected
                                ? Icons.call
                                : Icons.call_end,
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
                        color: state is CallConnected
                            ? Colors.green
                            : Colors.orange,
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

                    // Control Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Speaker Button
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

                        // Mute Button
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
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        // End Call Button
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

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
