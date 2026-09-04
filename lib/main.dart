
import 'dart:convert';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const aiServerUrl = String.fromEnvironment(
  'AI_SERVER_URL',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(AIRobotPROV2(cameras: cameras));
}

class AIRobotPROV2 extends StatelessWidget {
  final List<CameraDescription> cameras;
  const AIRobotPROV2({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Robot PRO v2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05080D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF178BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

class ChatItem {
  final String text;
  final bool robot;
  ChatItem(this.text, this.robot);
}

class RobotBrain {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final List<String> memory = [];
  SharedPreferences? prefs;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    memory
      ..clear()
      ..addAll(prefs?.getStringList('memory') ?? []);
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
  }

  Future<String> ask(String prompt, String language) async {
    if (aiServerUrl.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('$aiServerUrl/chat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'message': prompt,
                'language': language,
                'memory': memory.take(30).toList(),
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final answer = data['answer'];
          if (answer is String && answer.trim().isNotEmpty) return answer.trim();
        }
      } catch (_) {}
    }

    final p = prompt.toLowerCase();
    if (p.contains('مرحبا') || p.contains('اهلا') || p.contains('hello') || p.contains('hi')) {
      return language == 'ar'
          ? 'أهلاً بك! أنا AI Robot PRO v2. كيف أستطيع مساعدتك؟'
          : 'Hello! I am AI Robot PRO v2. How can I help you?';
    }
    if (p.contains('اسمك') || p.contains('name')) {
      return language == 'ar'
          ? 'اسمي AI Robot PRO v2.'
          : 'My name is AI Robot PRO v2.';
    }
    if (RegExp(r'(تذكر|احفظ|remember|save)', caseSensitive: false).hasMatch(prompt)) {
      final value = prompt
          .replaceFirst(RegExp(r'(تذكر|احفظ|remember|save)\s*', caseSensitive: false), '')
          .trim();
      if (value.isNotEmpty) {
        memory.add(value);
        await prefs?.setStringList('memory', memory);
      }
      return language == 'ar' ? 'تم حفظ المعلومة في ذاكرتي.' : 'I saved that in my memory.';
    }
    if (p.contains('ذاكرة') || p.contains('memory')) {
      return memory.isEmpty
          ? (language == 'ar' ? 'لا توجد معلومات محفوظة حاليًا.' : 'There are no saved memories yet.')
          : (language == 'ar'
              ? 'لدي ${memory.length} معلومة محفوظة.'
              : 'I have ${memory.length} saved memories.');
    }
    return language == 'ar'
        ? 'أنا في وضع عدم الاتصال بالخادم السحابي حاليًا. اربط AI_SERVER_URL في البناء لتفعيل الذكاء الاصطناعي الحقيقي.'
        : 'I am currently offline from the cloud AI server. Set AI_SERVER_URL at build time to enable the real AI service.';
  }

  Future<void> speak(String text, String language) async {
    await tts.setLanguage(language == 'ar' ? 'ar-SA' : 'en-US');
    await tts.speak(text);
  }

  Future<bool> startListening({
    required String language,
    required ValueChanged<String> onText,
    required VoidCallback onDone,
  }) async {
    final ok = await speech.initialize();
    if (!ok) return false;
    await speech.listen(
      options: stt.SpeechListenOptions(
        localeId: language == 'ar' ? 'ar_SA' : 'en_US',
      ),
      onResult: (result) {
        onText(result.recognizedWords);
        if (result.finalResult) onDone();
      },
    );
    return true;
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final brain = RobotBrain();
  final messageController = TextEditingController();
  final messages = <ChatItem>[];

  late final AnimationController pulse;
  String language = 'ar';
  String emotion = 'idle';
  String character = 'Metal Classic';
  bool listening = false;
  bool thinking = false;
  int navIndex = 0;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    brain.init().then((_) {
      setState(() {
        messages.add(ChatItem(
          language == 'ar'
              ? 'مرحباً 👋 أنا مساعدك الشخصي. كيف أستطيع مساعدتك اليوم؟'
              : 'Hello 👋 I am your personal assistant. How can I help today?',
          true,
        ));
      });
    });
  }

  @override
  void dispose() {
    pulse.dispose();
    messageController.dispose();
    brain.tts.stop();
    super.dispose();
  }

  Future<void> sendMessage([String? incoming]) async {
    final text = (incoming ?? messageController.text).trim();
    if (text.isEmpty) return;
    messageController.clear();
    setState(() {
      messages.add(ChatItem(text, false));
      thinking = true;
      emotion = 'thinking';
    });
    final reply = await brain.ask(text, language);
    if (!mounted) return;
    setState(() {
      thinking = false;
      emotion = 'talking';
      messages.add(ChatItem(reply, true));
    });
    await brain.speak(reply, language);
    if (mounted) setState(() => emotion = 'happy');
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => emotion = 'idle');
  }

  Future<void> toggleMic() async {
    if (listening) {
      await brain.speech.stop();
      if (mounted) {
        setState(() {
          listening = false;
          emotion = 'idle';
        });
      }
      return;
    }
    setState(() {
      listening = true;
      emotion = 'listening';
    });
    final ok = await brain.startListening(
      language: language,
      onText: (text) {
        messageController.text = text;
        setState(() {});
      },
      onDone: () {
        if (mounted) {
          setState(() => listening = false);
          if (messageController.text.trim().isNotEmpty) sendMessage();
        }
      },
    );
    if (!ok && mounted) {
      setState(() {
        listening = false;
        emotion = 'idle';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language == 'ar'
              ? 'تعذر تشغيل الميكروفون. تأكد من صلاحية الميكروفون.'
              : 'Microphone unavailable. Check microphone permission.'),
        ),
      );
    }
  }

  void openCamera() {
    if (widget.cameras.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(camera: widget.cameras.first),
      ),
    );
  }

  void showMemory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(language == 'ar' ? '🧠 الذاكرة الشخصية' : '🧠 Personal Memory',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (brain.memory.isEmpty)
                    Text(language == 'ar' ? 'الذاكرة فارغة.' : 'Memory is empty.')
                  else
                    SizedBox(
                      height: 300,
                      child: ListView(
                        children: brain.memory.reversed
                            .map((m) => ListTile(
                                  leading: const Icon(Icons.bookmark_outline),
                                  title: Text(m),
                                ))
                            .toList(),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () async {
                      brain.memory.clear();
                      await brain.prefs?.setStringList('memory', brain.memory);
                      setSheet(() {});
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: Text(language == 'ar' ? 'حذف الذاكرة' : 'Clear memory'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showCharacters() {
    final chars = [
      ('Metal Classic', '🤖', 'مساعد شخصي'),
      ('Space AI', '🚀', 'مستكشف'),
      ('Teacher Bot', '📚', 'تعليمي'),
      ('Friend Bot', '😊', 'رفيق'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: chars.map((c) {
          return ListTile(
            leading: Text(c.$2, style: const TextStyle(fontSize: 28)),
            title: Text(c.$1),
            subtitle: Text(c.$3),
            trailing: character == c.$1 ? const Icon(Icons.check_circle, color: Colors.cyan) : null,
            onTap: () async {
              setState(() => character = c.$1);
              await brain.prefs?.setString('character', character);
              if (mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void showSmartHome() {
    final devices = <String, bool>{
      'الإضاءة': false,
      'التلفاز': false,
      'التكييف': false,
    };
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('🏠 Smart Home',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...devices.keys.map((d) => SwitchListTile(
                  title: Text(d),
                  value: devices[d]!,
                  onChanged: (v) {
                    devices[d] = v;
                    setSheet(() {});
                  },
                )),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'واجهة التحكم جاهزة للربط مع Home Assistant أو MQTT. الأجهزة الحالية محاكاة.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = language == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF05080D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: RichText(
            text: const TextSpan(
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              children: [
                TextSpan(text: 'AI Robot '),
                TextSpan(text: 'PRO v2', style: TextStyle(color: Colors.cyanAccent)),
              ],
            ),
          ),
          leading: IconButton(onPressed: showCharacters, icon: const Icon(Icons.menu)),
          actions: [
            IconButton(onPressed: () => setState(() => language = language == 'ar' ? 'en' : 'ar'),
                icon: Text(language == 'ar' ? 'EN' : 'ع')),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Chip(
                  avatar: const CircleAvatar(radius: 5, backgroundColor: Colors.greenAccent),
                  label: const Text('ONLINE'),
                ),
                Text(character, style: const TextStyle(color: Colors.white70)),
              ],
            ),
            SizedBox(
              height: 420,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => CustomPaint(
                  painter: InteractiveRobotPainter(
                    t: pulse.value,
                    emotion: emotion,
                    listening: listening,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 340),
                      child: Text(
                        emotion == 'thinking'
                            ? (rtl ? 'أفكر...' : 'Thinking...')
                            : emotion == 'listening'
                                ? (rtl ? 'أستمع إليك...' : 'Listening...')
                                : emotion == 'talking'
                                    ? (rtl ? 'أتحدث...' : 'Speaking...')
                                    : (rtl ? 'كيف أساعدك؟' : 'How can I help?'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  ...messages.map((m) => Align(
                        alignment: m.robot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(13),
                          constraints: const BoxConstraints(maxWidth: 350),
                          decoration: BoxDecoration(
                            color: m.robot ? const Color(0xFF101A25) : const Color(0xFF0C2C40),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: m.robot
                                  ? Colors.white12
                                  : Colors.cyanAccent.withValues(alpha: .18),
                            ),
                          ),
                          child: Text(m.text, style: const TextStyle(fontSize: 15.5)),
                        ),
                      )),
                  if (thinking)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('•••', style: TextStyle(color: Colors.cyanAccent, fontSize: 25)),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF081019),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: toggleMic,
                          style: IconButton.styleFrom(
                            backgroundColor: listening ? Colors.redAccent : const Color(0xFF1266CC),
                          ),
                          icon: Icon(listening ? Icons.stop : Icons.mic),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            onSubmitted: (_) => sendMessage(),
                            decoration: InputDecoration(
                              hintText: rtl ? 'اكتب رسالتك...' : 'Type your message...',
                              filled: true,
                              fillColor: const Color(0xFF0D141D),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => sendMessage(),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _QuickAction(icon: Icons.chat_bubble_outline, text: rtl ? 'المحادثة' : 'Chat',
                            onTap: () => setState(() => navIndex = 1)),
                        _QuickAction(icon: Icons.camera_alt_outlined, text: rtl ? 'الرؤية' : 'Vision',
                            onTap: openCamera),
                        _QuickAction(icon: Icons.psychology_outlined, text: rtl ? 'الذاكرة' : 'Memory',
                            onTap: showMemory),
                        _QuickAction(icon: Icons.home_outlined, text: rtl ? 'المنزل' : 'Home',
                            onTap: showSmartHome),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: Colors.cyanAccent),
                const SizedBox(height: 3),
                Text(text, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}

class InteractiveRobotPainter extends CustomPainter {
  final double t;
  final String emotion;
  final bool listening;
  InteractiveRobotPainter({required this.t, required this.emotion, required this.listening});

  @override
  void paint(Canvas c, Size s) {
    final x = s.width / 2;
    final bob = math.sin(t * math.pi * 2) * 5;
    c.save();
    c.translate(x, 20 + bob);

    final glow = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: .09)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    c.drawCircle(const Offset(0, 165), 125, glow);

    final metal = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF1F5F8), Color(0xFF89939C), Color(0xFF272E35)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(-120, 0, 240, 290));

    final dark = Paint()..color = const Color(0xFF0B1118);
    final cyan = Paint()..color = Colors.cyanAccent;

    // torso
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-88, 185, 176, 150), const Radius.circular(42)), metal);
    // shoulders
    c.drawCircle(const Offset(-92, 215), 34, metal);
    c.drawCircle(const Offset(92, 215), 34, metal);
    // arms
    final armY = math.sin(t * math.pi * 2) * 7;
    c.save(); c.translate(-118, 240); c.rotate(-0.06 + armY * .006);
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, -5, 31, 110), const Radius.circular(15)), metal);
    c.restore();
    c.save(); c.translate(118, 240); c.rotate(0.06 - armY * .006);
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, -5, 31, 110), const Radius.circular(15)), metal);
    c.restore();

    // core
    c.drawCircle(const Offset(0, 245), 28, dark);
    c.drawCircle(const Offset(0, 245), 14 + math.sin(t * math.pi * 4) * 2, cyan);

    // neck
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-25, 145, 50, 55), const Radius.circular(15)), dark);

    // head
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-105, 15, 210, 135), const Radius.circular(48)), metal);
    c.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-80, 35, 160, 92), const Radius.circular(32)), dark);

    final eyeBaseY = 78.0;
    final eyeX = emotion == 'thinking' ? 7.0 : 0.0;
    final eyeW = emotion == 'talking' ? 30.0 : 34.0;
    c.drawOval(Rect.fromCenter(center: Offset(-35 + eyeX, eyeBaseY), width: eyeW, height: 22), cyan);
    c.drawOval(Rect.fromCenter(center: Offset(35 + eyeX, eyeBaseY), width: eyeW, height: 22), cyan);

    final mouth = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = emotion == 'talking' ? 7 : 4;
    final path = Path();
    if (emotion == 'happy') {
      path.moveTo(-25, 109); path.quadraticBezierTo(0, 130, 25, 109);
    } else if (emotion == 'thinking') {
      path.moveTo(-18, 113); path.quadraticBezierTo(0, 107, 18, 113);
    } else if (emotion == 'talking') {
      c.drawOval(Rect.fromCenter(
        center: const Offset(0, 112),
        width: 30,
        height: 13 + math.sin(t * math.pi * 10).abs() * 8,
      ), mouth);
    } else {
      path.moveTo(-20, 112); path.lineTo(20, 112);
    }
    if (emotion != 'talking') c.drawPath(path, mouth);

    // listening ring
    if (listening) {
      final ring = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final r = 125 + math.sin(t * math.pi * 2) * 8;
      c.drawCircle(const Offset(0, 82), r, ring);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant InteractiveRobotPainter oldDelegate) => true;
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  const CameraPage({super.key, required this.camera});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController controller;
  late final Future<void> init;
  @override
  void initState() {
    super.initState();
    controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    init = controller.initialize();
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI Vision')),
        body: FutureBuilder<void>(
          future: init,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('Camera error: ${snap.error}'));
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned(
                  left: 20, right: 20, bottom: 25,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final photo = await controller.takePicture();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Captured: ${photo.path}')),
                      );
                    },
                    icon: const Icon(Icons.camera),
                    label: const Text('Capture'),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
