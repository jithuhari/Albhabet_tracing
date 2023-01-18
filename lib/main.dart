import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_digital_ink_recognition/learning_digital_ink_recognition.dart';
import 'package:learning_input_image/learning_input_image.dart';
import 'package:provider/provider.dart';

import 'painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryTextTheme: const TextTheme(
          headline6: TextStyle(color: Colors.white),
        ),
      ),
      home: ChangeNotifierProvider(
        create: (_) => DigitalInkRecognitionState(),
        child: const DigitalInkRecognitionPage(),
      ),
    );
  }
}

class DigitalInkRecognitionPage extends StatefulWidget {
  const DigitalInkRecognitionPage({Key? key}) : super(key: key);

  @override
  _DigitalInkRecognitionPageState createState() =>
      _DigitalInkRecognitionPageState();
}

class _DigitalInkRecognitionPageState extends State<DigitalInkRecognitionPage> {
  final String _model = 'en-US';

  DigitalInkRecognitionState get state => Provider.of(context, listen: false);
  late DigitalInkRecognition _recognition;

  double get _width => MediaQuery.of(context).size.width;
  double height = 360;

  @override
  void initState() {
    _recognition = DigitalInkRecognition(model: _model);
    super.initState();
  }

  @override
  void dispose() {
    _recognition.dispose();
    super.dispose();
  }

  // need to call start() at the first time before painting the ink
  Future<void> _init() async {
    //print('Writing Area: ($_width, $_height)');
    await _recognition.start(writingArea: Size(_width, height));
    // always check the availability of model before being used for recognition
    await _checkModel();
  }

  // reset the ink recognition
  Future<void> _reset() async {
    state.reset();
    await _recognition.start(writingArea: Size(_width, height));
  }

  Future<void> _checkModel() async {
    bool isDownloaded = await DigitalInkModelManager.isDownloaded(_model);

    if (!isDownloaded) {
      await DigitalInkModelManager.download(_model);
    }
  }

  Future<void> _actionDown(Offset point) async {
    state.startWriting(point);
    await _recognition.actionDown(point);
  }

  Future<void> _actionMove(Offset point) async {
    state.writePoint(point);
    await _recognition.actionMove(point);
  }

  Future<void> _actionUp() async {
    state.stopWriting();
    await _recognition.actionUp();
  }

  Future<void> _startRecognition() async {
    if (state.isNotProcessing) {
      state.startProcessing();
      // always check the availability of model before being used for recognition
      await _checkModel();
      state.data = await _recognition.process();
      state.stopProcessing();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Alphabet Tracing App'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Builder(
              builder: (_) {
                _init();

                return GestureDetector(
                  onScaleStart: (details) async =>
                      await _actionDown(details.localFocalPoint),
                  onScaleUpdate: (details) async =>
                      await _actionMove(details.localFocalPoint),
                  onScaleEnd: (details) async => await _actionUp(),
                  child: Consumer<DigitalInkRecognitionState>(
                    builder: (_, state, __) => Stack(
                      children: [
                        const Center(
                          child: Image(
                            //height: MediaQuery.of(context).size.height / 2.3,
                            image: NetworkImage(
                                'https://raw.githubusercontent.com/McoyJiang/TracingSample/master/tracinglibrary/src/main/assets/letter/4_bg.png'),
                          ),
                        ),
                        const Center(
                          child: Image(
                            //height: MediaQuery.of(context).size.height / 2.3,
                            image: NetworkImage(
                                'https://raw.githubusercontent.com/McoyJiang/TracingSample/master/tracinglibrary/src/main/assets/trace/4_tracing.png'),
                          ),
                        ),
                        Center(
                          child: CustomPaint(
                            painter:
                                DigitalInkPainter(writings: state.writings),
                            child: SizedBox(
                              width: _width,
                              height: height,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const SizedBox(height: 15),
                SizedBox(
                  width: _width / 2,
                  child: NormalPinkButton(
                    text: 'Start Recognition',
                    onPressed: _startRecognition,
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: _width / 2,
                  child: NormalBlueButton(
                    text: 'Reset Canvas',
                    onPressed: _reset,
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Consumer<DigitalInkRecognitionState>(
                      builder: (_, state, __) {
                    if (state.isNotProcessing && state.isNotEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            state.toCompleteString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }

                    if (state.isProcessing) {
                      return Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          color: Colors.transparent,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    return Container();
                  }),
                ),
                Expanded(child: Container()),
              ],
            ),
          ),
          // SizedBox(height: 20),
        ],
      ),
    );
  }
}

class DigitalInkRecognitionState extends ChangeNotifier {
  List<List<Offset>> _writings = [];
  List<RecognitionCandidate> _data = [];
  bool isProcessing = false;

  List<List<Offset>> get writings => _writings;
  List<RecognitionCandidate> get data => _data;
  bool get isNotProcessing => !isProcessing;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  List<Offset> _writing = [];

  void reset() {
    _writings = [];
    notifyListeners();
  }

  void startWriting(Offset point) {
    _writing = [point];
    _writings.add(_writing);
    notifyListeners();
  }

  void writePoint(Offset point) {
    if (_writings.isNotEmpty) {
      _writings[_writings.length - 1].add(point);
      notifyListeners();
    }
  }

  void stopWriting() {
    _writing = [];
    notifyListeners();
  }

  void startProcessing() {
    isProcessing = true;
    notifyListeners();
  }

  void stopProcessing() {
    isProcessing = false;
    notifyListeners();
  }

  set data(List<RecognitionCandidate> data) {
    _data = data;
    notifyListeners();
  }

  @override
  String toString() {
    return isNotEmpty ? _data.first.text : '';
  }

  String toCompleteString() {
    //return isNotEmpty ? _data.map((c) => c.text).toList().join(', ') : '';
    return isNotEmpty ? _data.map((c) => c.text).first : '';
  }
}
