import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../services/media_type_helpers.dart';

const profileVideoMaxSeconds = 5;

Future<String?> validateProfileVideoFile(XFile file) async {
  if (mediaTypeForFile(file) != 'video') return null;

  VideoPlayerController? controller;
  try {
    controller = VideoPlayerController.file(File(file.path));
    await controller.initialize();
    final seconds = controller.value.duration.inMilliseconds / 1000.0;
    if (seconds > profileVideoMaxSeconds + 0.25) {
      return 'Profile videos must be $profileVideoMaxSeconds seconds or shorter.';
    }
    return null;
  } catch (_) {
    return 'Unable to read that video. Try another clip.';
  } finally {
    await controller?.dispose();
  }
}
