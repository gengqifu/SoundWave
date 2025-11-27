import 'package:flutter/material.dart';

import 'audio_controller.dart';
import 'audio_state.dart';

/// 简易状态展示组件，验证状态流绑定（占位 UI，可替换为正式设计）。
class AudioStatusView extends StatelessWidget {
  const AudioStatusView({super.key, required this.controller});

  final AudioController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioState>(
      stream: controller.states,
      initialData: controller.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? AudioState.initial();
        final status = state.error != null
            ? 'Error: ${state.error}'
            : state.isPlaying
                ? 'Playing'
                : 'Paused';
        final buffered = state.bufferedPosition != null
            ? _format(state.bufferedPosition!)
            : '--:--';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status', key: const Key('status_text')),
            Text(
              'Position: ${_format(state.position)} / ${_format(state.duration)}',
              key: const Key('position_text'),
            ),
            Text('Buffered: $buffered', key: const Key('buffer_text')),
          ],
        );
      },
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
