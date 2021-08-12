import 'dart:io';

import 'package:flutter/material.dart';
import 'package:helpers/helpers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_editor/video_editor.dart';

import 'video_compressor_encoder.dart';

//-------------------//
//PICKUP VIDEO SCREEN//
//-------------------//
class VideoPickerPage extends StatefulWidget {
  final TargetPlatform platform;
  const VideoPickerPage({@required this.platform});
  @override
  _VideoPickerPageState createState() => _VideoPickerPageState();
}

class _VideoPickerPageState extends State<VideoPickerPage> {
  // final ImagePicker _picker = ImagePicker();

  void _pickVideo() async {
    final File file = await ImagePicker.pickVideo(source: ImageSource.gallery);
    if (file != null)
      context.to(VideoEditor(
        file: file,
        platform: widget.platform,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Image / Video Picker")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextDesigned(
              "Click on Pick Video to select video",
              color: Colors.black,
              size: 18.0,
            ),
            ElevatedButton(
              onPressed: _pickVideo,
              child: Text("Pick Video From Gallery"),
            ),
          ],
        ),
      ),
    );
  }
}

//-------------------//
//VIDEO EDITOR SCREEN//
//-------------------//
class VideoEditor extends StatefulWidget {
  VideoEditor({Key key, @required this.file, @required this.platform})
      : super(key: key);

  final File file;
  final TargetPlatform platform;
  @override
  _VideoEditorState createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final double height = 60;
  String _localPath = "";
  bool _exported = false;
  String _exportText = "";
  VideoEditorController _controller;
  Future<String> _findLocalPath() async {
    final directory = widget.platform == TargetPlatform.android
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _prepareSaveDir() async {
    _localPath =
        await _findLocalPath() + Platform.pathSeparator + "ExportedVideos";
    print(_localPath);
    print("##############################################");
    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create(recursive: true);
    }
  }

  @override
  void initState() {
    print("From Init State Vide Editing");
    print(widget.file);
    print("From Init State Vide Editing");
    _controller = VideoEditorController.file(widget.file)
      ..initialize().then((_) => setState(() {}));
    _prepareSaveDir();
    super.initState();
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openCropScreen() => context.to(CropScreen(controller: _controller));

  void _exportVideo() async {
    Misc.delayed(1000, () => _isExporting.value = true);
    //NOTE: To use [-crf 17] and [VideoExportPreset] you need ["min-gpl-lts"] package
    final File file = await _controller.exportVideo(
      // preset: VideoExportPreset.medium,
      // customInstruction: "-crf 17",
      localPath: _localPath + Platform.pathSeparator,
      onProgress: (statics) {
        if (_controller.video != null) {
          _exportingProgress.value =
              statics.time / _controller.video.value.duration.inMilliseconds;
        }
      },
    );
    _isExporting.value = false;

    if (file != null) {
      _exportText = "Video success export to ${file.path}!";
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => TalentLairCompress(file, widget.platform)));
    } else {
      _exportText = "Error on export video :(";
    }

    setState(() => _exported = true);
    Misc.delayed(2000, () => setState(() => _exported = false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.initialized
          ? Stack(children: [
              Column(children: [
                _topNavBar(),
                Expanded(
                  child: CropGridViewer(
                    controller: _controller,
                    showGrid: false,
                  ),
                ),
                ..._trimSlider(),
              ]),
              Center(
                child: AnimatedBuilder(
                  animation: _controller.video,
                  builder: (_, __) => OpacityTransition(
                    visible: !_controller.isPlaying,
                    child: GestureDetector(
                      onTap: _controller.video.play,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow),
                      ),
                    ),
                  ),
                ),
              ),
              _customSnackBar(),
              ValueListenableBuilder(
                valueListenable: _isExporting,
                builder: (_, bool export, __) => OpacityTransition(
                  visible: export,
                  child: AlertDialog(
                    title: ValueListenableBuilder(
                      valueListenable: _exportingProgress,
                      builder: (_, double value, __) => TextDesigned(
                        "Exporting video ${(value * 100).ceil()}%",
                        color: Colors.black,
                        bold: true,
                      ),
                    ),
                  ),
                ),
              )
            ])
          : Center(child: CircularProgressIndicator()),
    );
  }

  Widget _topNavBar() {
    return SafeArea(
      child: Container(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _controller.rotate90Degrees(RotateDirection.left),
                child: Icon(Icons.rotate_left, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _controller.rotate90Degrees(RotateDirection.right),
                child: Icon(Icons.rotate_right, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _openCropScreen,
                child: Icon(Icons.crop, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _exportVideo,
                child: Icon(Icons.save, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) => [
        duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
        duration.inSeconds.remainder(60).toString().padLeft(2, '0')
      ].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: _controller.video,
        builder: (_, __) {
          final duration = _controller.video.value.duration.inSeconds;
          final pos = _controller.trimPosition * duration;
          final start = _controller.minTrim * duration;
          final end = _controller.maxTrim * duration;

          return Padding(
            padding: Margin.horizontal(height / 4),
            child: Row(children: [
              TextDesigned(
                formatter(Duration(seconds: pos.toInt())),
                color: Colors.white,
              ),
              Expanded(child: SizedBox()),
              OpacityTransition(
                visible: _controller.isTrimming,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextDesigned(
                    formatter(Duration(seconds: start.toInt())),
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  TextDesigned(
                    formatter(Duration(seconds: end.toInt())),
                    color: Colors.white,
                  ),
                ]),
              )
            ]),
          );
        },
      ),
      Container(
        height: height,
        margin: Margin.all(height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
        ),
      )
    ];
  }

  Widget _customSnackBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SwipeTransition(
        visible: _exported,
        // direction: SwipeDirection.fromBottom,
        child: Container(
          height: height,
          width: double.infinity,
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: TextDesigned(
              _exportText,
              color: Colors.white,
              bold: true,
            ),
          ),
        ),
      ),
    );
  }
}

//-----------------//
//CROP VIDEO SCREEN//
//-----------------//
class CropScreen extends StatelessWidget {
  CropScreen({Key key, @required this.controller}) : super(key: key);

  final VideoEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: Margin.all(30),
          child: Column(children: [
            Expanded(
              child: AnimatedInteractiveViewer(
                maxScale: 2.4,
                child: CropGridViewer(controller: controller),
              ),
            ),
            SizedBox(height: 15),
            Row(children: [
              Expanded(
                child: SplashTap(
                  onTap: context.goBack,
                  child: Center(
                    child: TextDesigned(
                      "CANCELAR",
                      color: Colors.white,
                      bold: true,
                    ),
                  ),
                ),
              ),
              buildSplashTap("16:9", 16 / 9, padding: Margin.horizontal(10)),
              buildSplashTap("1:1", 1 / 1),
              buildSplashTap("4:5", 4 / 5, padding: Margin.horizontal(10)),
              buildSplashTap("NO", null, padding: Margin.right(10)),
              Expanded(
                child: SplashTap(
                  onTap: () {
                    //2 WAYS TO UPDATE CROP
                    //WAY 1:
                    controller.updateCrop();
                    /*WAY 2:
                    controller.minCrop = controller.cacheMinCrop;
                    controller.maxCrop = controller.cacheMaxCrop;
                    */
                    context.goBack();
                  },
                  child: Center(
                    child: TextDesigned("OK", color: Colors.white, bold: true),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget buildSplashTap(
    String title,
    double aspectRatio, {
    EdgeInsetsGeometry padding,
  }) {
    return SplashTap(
      onTap: () => controller.preferredCropAspectRatio = aspectRatio,
      child: Padding(
        padding: padding ?? Margin.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.aspect_ratio, color: Colors.white),
            TextDesigned(title, color: Colors.white, bold: true),
          ],
        ),
      ),
    );
  }
}
