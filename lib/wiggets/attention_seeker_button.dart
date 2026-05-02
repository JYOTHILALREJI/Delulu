import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vibration/vibration.dart';

class AttentionSeekerButton extends StatefulWidget {
  final String peerId;
  final IO.Socket socket;
  const AttentionSeekerButton({super.key, required this.peerId, required this.socket});

  @override
  State<AttentionSeekerButton> createState() => _AttentionSeekerButtonState();
}

class _AttentionSeekerButtonState extends State<AttentionSeekerButton> {
  bool _isVibrating = false;

  void _startVibration() {
    if (_isVibrating) return;
    setState(() => _isVibrating = true);
    widget.socket.emit('attention_start', {'toUserId': widget.peerId});
    Vibration.vibrate(pattern: [0, 500, 1000], repeat: 2);
  }

  void _stopVibration() {
    if (!_isVibrating) return;
    setState(() => _isVibrating = false);
    widget.socket.emit('attention_stop', {'toUserId': widget.peerId});
    Vibration.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startVibration(),
      onLongPressEnd: (_) => _stopVibration(),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFBD00FF),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.white),
              SizedBox(width: 8),
              Text('Hold for Attention', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}