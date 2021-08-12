import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'a_lone_compressor.dart';
import 'camera_show_example_route.dart';
import 'video_editing_route.dart';

List<CameraDescription> cameras = [];
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    return MaterialApp(
      title: 'Youtube Video Downloader & Editor & Compressor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Youtube Video Downloader & Editor & Compressor',
        platform: platform,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  TargetPlatform platform;
  MyHomePage({@required this.title, @required this.platform});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String debug = '';
  String _localPath = "";
  Future<PermissionStatus> getPermission() async {
    print("getPermission");
    var status = await Permission.storage.request();
    return status;
  }

  @override
  void initState() {
    _prepareSaveDir();
    super.initState();
  }

   ElevatedButton debugButton;

  final myController = TextEditingController();
  Image thumbnail = Image(image: AssetImage('lib/assets/images/yt.jpg'));
  var title = '';
  var id;
  var author = '';
  var len = '';
  var qualityList;
  var size = '';

  void getInfo(String text) async {
    try {
      setState(() {
        loadLock = true;
        debug = 'FETCHING INFO';
      });
      var yt = YoutubeExplode();
      var video = await yt.videos.get(myController.text);

      title = video.title;
      id = video.id;
      thumbnail = Image.network(video.thumbnails.highResUrl);
      author = video.author;
      len = video.duration.toString();
      var manifest = await yt.videos.streamsClient.getManifest(id);
      qualityList = toList(manifest.muxed);
      setState(() {
        selectedQuality = manifest.muxed.withHighestBitrate();
        var f = NumberFormat("######0.0#", "en_US");
        size = '${f.format(selectedQuality.size.totalMegaBytes)} MB';
      });

      setState(() {
        loadLock = false;
        debug = 'READY TO DOWNLOAD';
      });
    } catch (e) {
      print(e.toString());
      setState(() {
        loadLock = false;
        debug = e.toString();
      });
    }
  }

  List<DropdownMenuItem<MuxedStreamInfo>> toList(
      Iterable<MuxedStreamInfo> infos) {
    List<DropdownMenuItem<MuxedStreamInfo>> list = [];
    for (MuxedStreamInfo info in infos) {
      list.add(DropdownMenuItem(
        value: info,
        child: Text(info.videoQualityLabel),
      ));
    }
    return list;
  }

  void download() async {
    var status = await getPermission();
    if (status.isGranted) {
      try {
        setState(() {
          loadLock = true;
          debug = 'FETCHING INFO';
        });
        var yt = YoutubeExplode();
        var video = await yt.videos.get(id);
        var title = video.title;

        if (selectedQuality != null) {
          var qualityLabel = selectedQuality.videoQualityLabel;
          setState(() {
            debug = 'DOWNLOADING $qualityLabel $title)';
          });
          var stream = yt.videos.streamsClient.get(selectedQuality);

          String title2 = title.replaceAll(" ", "");
          String qualityLabel2 = qualityLabel.replaceAll(" ", "");
          var file = File('$_localPath/$title2-$qualityLabel2.mp4');
          var fileStream = file.openWrite();
          var len = 0;
          var maxLen = selectedQuality.size.totalBytes;

          stream.listen((value) async {
            len += value.length;
            var progress = len / maxLen * 100;
            var f = NumberFormat("##0.0#", "en_US");
            setState(() {
              debug = f.format(progress) + '%';
            });
            fileStream.add(value);
          }).onDone(() async {
            await fileStream.flush();
            await fileStream.close();
            setState(() {
              debug = title + ' saved to $_localPath folder';
              loadLock = false;
            });
            print('done');
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => VideoEditor(
                      file: file,
                      platform: widget.platform,
                    )));
          });
        }
      } catch (e) {
        print(e.toString());
        setState(() {
          loadLock = false;
          debug = e.toString();
        });
      }
    }
  }

  MuxedStreamInfo selectedQuality;

  onChange(MuxedStreamInfo info) {
    setState(() {
      selectedQuality = info;
      var f = NumberFormat("######0.0#", "en_US");
      size = '${f.format(selectedQuality.size.totalMegaBytes)} MB';
    });
  }

  bool loadLock = false;

  @override
  Widget build(BuildContext context) {
    var downloadCall;
    if (!loadLock && id != null) {
      downloadCall = () {
        loadLock = true;
        setState(() {});
        download();
      };
    }

    var fetchCall;
    if (!loadLock) {
      fetchCall = () {
        loadLock = true;
        setState(() {});
        getInfo(myController.text);
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Enter yt link here:'),
              Row(children: <Widget>[
                Flexible(
                  child: Padding(
                    child: TextField(controller: myController),
                    padding: EdgeInsets.all(10.0),
                  ),
                  flex: 3,
                ),
                Flexible(
                  child: ElevatedButton(
                      onPressed: fetchCall, child: Text("Fetch info")),
                  flex: 1,
                  fit: FlexFit.loose,
                )
              ]),
              Text('$debug'),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Flexible(child: thumbnail, flex: 1),
                    Flexible(
                        child: Padding(
                          child: Column(
                            children: [
                              Text(
                                "title: $title",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "author: $author",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "length: $len",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "size: $size",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            crossAxisAlignment: CrossAxisAlignment.start,
                          ),
                          padding: EdgeInsets.all(5),
                        ),
                        flex: 2),
                  ],
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
              Padding(
                child: Row(
                  children: [
                    Flexible(
                      child: DropdownButton(
                        items: qualityList,
                        value: selectedQuality,
                        onChanged: onChange,
                      ),
                      flex: 1,
                      fit: FlexFit.loose,
                    ),
                    Flexible(
                      child: ElevatedButton(
                          onPressed: downloadCall, child: Text("DOWNLOAD")),
                      flex: 1,
                    ),
                  ],
                  mainAxisAlignment: MainAxisAlignment.center,
                ),
                padding: EdgeInsets.all(10.0),
              ),
              Container(
                width: 100,
                height: 50,
                margin: const EdgeInsets.only(left: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue,
                ),
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Colors.white,
                      onTap: () async {
                        print("Hello World");
                        print(cameras);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => CameraExampleHome(
                                cameras: cameras, platform: widget.platform)));
                      },
                      child: Center(
                        child: Text("Record Video",
                            style: const TextStyle(color: Colors.white)),
                      ),
                    )),
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                width: 100,
                height: 50,
                margin: const EdgeInsets.only(left: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue,
                ),
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Colors.white,
                      onTap: () async {
                        print("Hello Worl");

                        print(cameras);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => VideoPickerPage(
                                  platform: widget.platform,
                                )));
                      },
                      child: const Center(
                        child: Text("Edit Video",
                            style: const TextStyle(color: Colors.white)),
                      ),
                    )),
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                width: 100,
                alignment: Alignment.center,
                height: 50,
                margin: const EdgeInsets.only(left: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue,
                ),
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Colors.white,
                      onTap: () async {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AloneCompressor()));
                      },
                      child: const Center(
                        child: Text(
                          "Compress Video",
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _findLocalPath() async {
    final directory = widget.platform == TargetPlatform.android
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _prepareSaveDir() async {
    _localPath =
        await _findLocalPath() + Platform.pathSeparator + "YoutubeVideos";
    print("##############################################");
    print(_localPath);
    print("##############################################");
    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create(recursive: true);
    }
  }
}
