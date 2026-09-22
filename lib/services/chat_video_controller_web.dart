import 'package:video_player/video_player.dart';

VideoPlayerController localChatVideoController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
