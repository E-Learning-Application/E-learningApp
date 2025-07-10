import 'package:flutter/material.dart';
import 'package:e_learning_app/core/model/match_response.dart';
import 'package:e_learning_app/core/service/webrtc_service.dart';
import 'package:e_learning_app/core/service/signalr_service.dart';

class CallScreen extends StatefulWidget {
  final MatchResponse match;
  final WebRTCService webRTCService;
  final SignalRService signalRService;
  final bool isVideo;

  const CallScreen({
    Key? key,
    required this.match,
    required this.webRTCService,
    required this.signalRService,
    required this.isVideo,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _callActive = true;

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    const baseUrl = 'https://elearningproject.runasp.net';
    return '$baseUrl$path';
  }

  @override
  void initState() {
    super.initState();
    // Optionally initialize WebRTC or other logic here
  }

  @override
  void dispose() {
    widget.webRTCService.dispose();
    super.dispose();
  }

  void _endCall() {
    setState(() {
      _callActive = false;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? 'Video Call' : 'Voice Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
          ),
        ],
      ),
      body: Center(
        child: _callActive
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage:
                        widget.match.matchedUser.profilePicture != null
                            ? NetworkImage(getFullImageUrl(
                                widget.match.matchedUser.profilePicture!))
                            : null,
                    child: widget.match.matchedUser.profilePicture == null
                        ? Text(
                            widget.match.matchedUser.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32))
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.match.matchedUser.username,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.isVideo
                      ? 'Video Call in progress...'
                      : 'Voice Call in progress...'),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call_end),
                    label: const Text('End Call'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _endCall,
                  ),
                ],
              )
            : const Text('Call ended.'),
      ),
    );
  }
}
