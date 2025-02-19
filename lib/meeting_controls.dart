import 'package:flutter/material.dart';

class MeetingControls extends StatelessWidget {
  final void Function() onToggleMicButtonPressed;
  final void Function() onToggleCameraButtonPressed;
  final void Function() onLeaveButtonPressed;
  final void Function() pipButtonPressed;
  const MeetingControls({
    super.key,
    required this.onToggleMicButtonPressed,
    required this.onToggleCameraButtonPressed,
    required this.onLeaveButtonPressed,
    required this.pipButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: onLeaveButtonPressed,
            child: const Text('Leave'),
          ),
          ElevatedButton(
            onPressed: pipButtonPressed,
            child: const Text('PIP'),
          ),
          ElevatedButton(
            onPressed: onToggleMicButtonPressed,
            child: const Text('Toggle Mic'),
          ),
          ElevatedButton(
            onPressed: onToggleCameraButtonPressed,
            child: const Text('Toggle WebCam'),
          ),
        ],
      ),
    );
  }
}
