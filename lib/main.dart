import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Test `FragmentShader.setImageSampler` memory leaks (Linux and Android simulator)
/// 
/// By running this app, memory leaks start to be noticed after 40~60 seconds
/// on the operating system monitor. 
/// Memory tab of DevTools doesn't report leaks.
/// 
/// This sample uses 2 shaders: `shader_a.frag` and `shader_b.frag`.
/// The shaders are drawn using `PictureRecorder()` and the output is stored 
/// into 2 different `ui.Image`s.
/// 
/// When pressing the button, the `Ticker` starts updating shader outputs.
/// `shader_a` uses the lastest output of `shader_b` as sampler2D uniform
/// and `shader_b` uses the latest output of itself.
/// 
/// Removing the sampler2D uniform from `shader_b.frag` (and of course 
/// the `setImageSampler` from `computeShader2()`), the leak doesn't occurs.
/// 


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test toImage leak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final painterStarted = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: painterStarted,
          builder: (_, start, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TestLeak(
                  key: UniqueKey(),
                  enabled: start,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => painterStarted.value = !painterStarted.value,
                  child: Text(start ? 'started' : 'stopped'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////
/// clear leaked cache mem (linux)
/// sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
class TestLeak extends StatefulWidget {
  const TestLeak({super.key, required this.enabled});

  final bool enabled;

  @override
  State<TestLeak> createState() => _TestLeakState();
}

class _TestLeakState extends State<TestLeak>
    with SingleTickerProviderStateMixin {
  late Ticker ticker;
  late Stopwatch sw;

  ui.FragmentProgram? program1;
  ui.FragmentShader? shader1;
  ui.FragmentProgram? program2;
  ui.FragmentShader? shader2;
  ui.Image? sampler1;
  ui.Image? sampler2;
  ui.Image? blankImage;

  bool isInited = false;
  Size size = const Size(700, 500);

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      sw = Stopwatch();
      ticker = createTicker(tick);
      if (widget.enabled) {
        ticker.start();
        sw.start();
      }

      init();
    }
  }

  @override
  void dispose() {
    if (widget.enabled) ticker.dispose();
    super.dispose();
  }

  Future<void> init() async {
    try {
      program1 = await ui.FragmentProgram.fromAsset('shaders/shader_a.frag');
      shader1 = program1?.fragmentShader();
      program2 = await ui.FragmentProgram.fromAsset('shaders/shader_b.frag');
      shader2 = program2?.fragmentShader();
    } on Exception catch (e) {
      debugPrint('Cannot load shader! $e');
      return;
    }

    try {
      final assetImageByteData =
          await rootBundle.load('assets/black_10x10.png');
      final codec = await ui.instantiateImageCodec(
        assetImageByteData.buffer.asUint8List(),
      );
      blankImage = (await codec.getNextFrame()).image;
    } on Exception catch (e) {
      debugPrint('Cannot load blankImage! $e');
      return;
    }

    isInited = true;
  }

  void tick(Duration elapsed) {
    if (!isInited) return;

    computeShader2();
    computeShader1();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!isInited) {
      return Container(
        color: Colors.black,
        width: size.width,
        height: size.height,
      );
    }

    /// Visualize the output of shader_a
    return RawImage(
      image: sampler1,
      width: size.width,
      height: size.height,
    );
  }

  void computeShader1() {
    shader1!
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, sampler2 ?? blankImage!);

    sampler1?.dispose();
    sampler1 = null;

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      Offset.zero & size,
      ui.Paint()..shader = shader1,
    );
    final picture = recorder.endRecording();

    sampler1 = picture.toImageSync(
      size.width.ceil(),
      size.height.ceil(),
    );
    picture.dispose();
  }

  void computeShader2() {
    shader2!
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, sw.elapsedMilliseconds / 1000) // iTime
      /// using just [blankImage], which is loaded at start, the issue doesn't occur
      ..setImageSampler(0, sampler2 ?? blankImage!);

    sampler2?.dispose();
    sampler2 = null;

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      Offset.zero & size,
      ui.Paint()..shader = shader2,
    );
    final picture = recorder.endRecording();

    sampler2 = picture.toImageSync(
      size.width.ceil(),
      size.height.ceil(),
    );
    picture.dispose();
  }
}
