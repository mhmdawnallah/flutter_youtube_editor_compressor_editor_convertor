import 'dart:io';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

class VideoPage extends StatelessWidget {
  final File outputFile;
  VideoPage(this.outputFile);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(
          0.85), // this is the main reason of transparency at next screen. I am ignoring rest implementation but what i have achieved is you can see.
      body: BetterPlayer(
        controller: BetterPlayerController(
          BetterPlayerConfiguration(aspectRatio: 1/2,autoPlay:  true),
          
          betterPlayerDataSource: BetterPlayerDataSource(
              BetterPlayerDataSourceType.file, outputFile.path),
        ),
      ),
    );
  }
}
