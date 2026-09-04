
import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
          seedColor: const Color(0xFF21A7FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

enum RobotState { idle, listening, thinking, speaking, happy }

class ChatItem {
  final String text;
  final bool robot;
  ChatItem(this.text, this.robot);
}

class PhoneControl {
  static const MethodChannel channel =
      MethodChannel('ai_robot_pro_v2/phone_control');

  static Future<bool> enabled() async {
    return await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  static Future<bool> settings() async {
    return await channel.invokeMethod<bool>('openAccessibilitySettings') ?? false;
  }

  static Future<bool> action(String name) async {
    return await channel.invokeMethod<bool>('action', {'name': name}) ?? false;
  }
}

class AssistantBrain {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  SharedPreferences? prefs;
  final List<String> memory = [];

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    memory.addAll(prefs?.getStringList('memory') ?? const []);
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
  }

  Future<String> answer(String text, String language) async {
    final t = text.toLowerCase();

    if (t.contains('مرحبا') || t.contains('اهلا') || t.contains('hello') ||
        t.contains('hi')) {
      return language == 'ar'
          ? 'أهلاً بك! أنا AI Robot PRO v2، مساعدك الشخصي.'
          : 'Hello! I am AI Robot PRO v2, your personal assistant.';
    }

    if (t.contains('اسمك') || t.contains('name')) {
      return language == 'ar'
          ? 'اسمي AI Robot PRO v2.'
          : 'My name is AI Robot PRO v2.';
    }

    final m = RegExp(
      r'(?:تذكر|احفظ|remember|save)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (m != null) {
      final value = m.group(1)?.trim() ?? '';
      if (value.isNotEmpty) {
        memory.add(value);
        await prefs?.setStringList('memory', memory);
      }
      return language == 'ar'
          ? 'تم حفظ المعلومة في ذاكرتي.'
          : 'Saved to my memory.';
    }

    if (t.contains('ذاكرة') || t.contains('memory')) {
      return memory.isEmpty
          ? (language == 'ar' ? 'ذاكرتي فارغة حاليًا.' : 'My memory is empty.')
          : (language == 'ar'
              ? 'لدي ${memory.length} معلومات محفوظة.'
              : 'I have ${memory.length} saved memories.');
    }

    return language == 'ar'
        ? 'أنا جاهز. اطلب مني فتح ميزة، التحدث معك، أو تنفيذ أحد أوامر الهاتف المسموحة.'
        : 'I am ready. Ask me to open a feature, talk with you, or run an allowed phone action.';
  }

  Future<void> speak(String text, String language) async {
    await tts.setLanguage(language == 'ar' ? 'ar-SA' : 'en-US');
    await tts.speak(text);
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final brain = AssistantBrain();
  final input = TextEditingController();
  final messages = <ChatItem>[];

  late final AnimationController avatarPulse;
  late final AnimationController ringPulse;

  String language = 'ar';
  RobotState state = RobotState.idle;
  String character = 'Metal Classic';
  bool listening = false;

  @override
  void initState() {
    super.initState();
    avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    ringPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    brain.init().then((_) {
      setState(() {
        messages.add(
          ChatItem(
            language == 'ar'
                ? 'مرحباً 👋 أنا مساعدك الشخصي. كيف أستطيع مساعدتك اليوم؟'
                : 'Hello 👋 I am your personal assistant. How can I help today?',
            true,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    avatarPulse.dispose();
    ringPulse.dispose();
    input.dispose();
    brain.tts.stop();
    super.dispose();
  }

  Future<void> send([String? value]) async {
    final text = (value ?? input.text).trim();
    if (text.isEmpty) return;
    input.clear();

    // Built-in phone actions.
    final p = text.toLowerCase();
    if (p.contains('اذهب إلى الرئيسية') || p.contains('الشاشة الرئيسية') ||
        p == 'home' || p.contains('go home')) {
      setState(() {
        messages.add(ChatItem(text, false));
        state = RobotState.thinking;
      });
      final ok = await PhoneControl.action('home');
      final reply = ok
          ? (language == 'ar' ? 'تم الانتقال إلى الشاشة الرئيسية.' : 'Home screen opened.')
          : (language == 'ar'
              ? 'فعّل صلاحية التحكم بالهاتف أولًا من الإعدادات.'
              : 'Enable phone control in settings first.');
      setState(() {
        state = RobotState.speaking;
        messages.add(ChatItem(reply, true));
      });
      await brain.speak(reply, language);
      if (mounted) setState(() => state = RobotState.happy);
      return;
    }

    setState(() {
      messages.add(ChatItem(text, false));
      state = RobotState.thinking;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    final reply = await brain.answer(text, language);

    setState(() {
      state = RobotState.speaking;
      messages.add(ChatItem(reply, true));
    });
    await brain.speak(reply, language);

    if (mounted) {
      setState(() => state = RobotState.happy);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => state = RobotState.idle);
      });
    }
  }

  Future<void> toggleMic() async {
    if (listening) {
      await brain.speech.stop();
      setState(() {
        listening = false;
        state = RobotState.idle;
      });
      return;
    }

    final ok = await brain.speech.initialize();
    if (!ok) {
      _snack(language == 'ar'
          ? 'الميكروفون أو التعرف على الكلام غير متاح.'
          : 'Microphone or speech recognition is unavailable.');
      return;
    }

    setState(() {
      listening = true;
      state = RobotState.listening;
    });

    await brain.speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: language == 'ar' ? 'ar_SA' : 'en_US',
      ),
      onResult: (r) {
        input.text = r.recognizedWords;
        setState(() {});
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          brain.speech.stop();
          setState(() => listening = false);
          send(r.recognizedWords);
        }
      },
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openCamera() {
    if (widget.cameras.isEmpty) {
      _snack(language == 'ar' ? 'لا توجد كاميرا.' : 'No camera available.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(camera: widget.cameras.first),
      ),
    );
  }

  void openMemory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B121B),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  language == 'ar' ? '🧠 ذاكرتي' : '🧠 My Memory',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: brain.memory.isEmpty
                      ? Text(language == 'ar'
                          ? 'لا توجد معلومات محفوظة.'
                          : 'No saved memories.')
                      : ListView(
                          shrinkWrap: true,
                          children: brain.memory.reversed
                              .map((m) => ListTile(
                                    leading: const Icon(Icons.bookmark_outline),
                                    title: Text(m),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    brain.memory.clear();
                    await brain.prefs?.setStringList('memory', brain.memory);
                    setSheet(() {});
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(language == 'ar' ? 'مسح الذاكرة' : 'Clear memory'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void openCharacters() {
    const chars = [
      ('Metal Classic', '🤖', 'المساعد الشخصي'),
      ('Space AI', '🚀', 'المستكشف'),
      ('Teacher Bot', '📚', 'المعلّم'),
      ('Friend Bot', '😊', 'الرفيق'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B121B),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: chars
            .map(
              (c) => ListTile(
                leading: Text(c.$2, style: const TextStyle(fontSize: 28)),
                title: Text(c.$1),
                subtitle: Text(c.$3),
                trailing: character == c.$1
                    ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
                    : null,
                onTap: () async {
                  setState(() => character = c.$1);
                  await brain.prefs?.setString('character', character);
                  if (mounted) Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void openPhoneControl() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B121B),
      builder: (_) => FutureBuilder<bool>(
        future: PhoneControl.enabled(),
        builder: (ctx, snap) {
          final enabled = snap.data == true;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                runSpacing: 10,
                children: [
                  ListTile(
                    leading: Icon(
                      enabled ? Icons.verified_user : Icons.lock_outline,
                      color: enabled ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    title: Text(
                      language == 'ar'
                          ? (enabled ? 'التحكم مفعّل' : 'التحكم غير مفعّل')
                          : (enabled ? 'Control enabled' : 'Control disabled'),
                    ),
                    subtitle: Text(
                      language == 'ar'
                          ? 'يجب تفعيل Accessibility يدويًا من Android.'
                          : 'Android Accessibility must be enabled manually.',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => PhoneControl.settings(),
                    icon: const Icon(Icons.settings_accessibility),
                    label: Text(language == 'ar'
                        ? 'فتح إعدادات إمكانية الوصول'
                        : 'Open Accessibility settings'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _ChipAction('Home', 'home'),
                      _ChipAction('Back', 'back'),
                      _ChipAction('Recents', 'recents'),
                      _ChipAction('Notifications', 'notifications'),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ChipAction(String label, String action) {
    return ActionChip(
      label: Text(label),
      onPressed: () async {
        final ok = await PhoneControl.action(action);
        _snack(ok
            ? '$label OK'
            : (language == 'ar'
                ? 'تعذر تنفيذ الأمر.'
                : 'Action failed.'));
      },
    );
  }

  void openTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B121B),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.explore, color: Colors.cyanAccent),
              title: Text(language == 'ar' ? 'البوصلة' : 'Compass'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CompassPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.cyanAccent),
              title: Text(language == 'ar' ? 'الطقس والحرارة' : 'Weather & Temperature'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WeatherDemoPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Colors.cyanAccent),
              title: Text(language == 'ar' ? 'الخرائط والملاحة' : 'Maps & Navigation'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MapDemoPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = language == 'ar';
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: 'AI Robot '),
                TextSpan(
                  text: 'PRO v2',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ],
            ),
          ),
          leading: IconButton(
            onPressed: openCharacters,
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(
                () => language = language == 'ar' ? 'en' : 'ar',
              ),
              icon: Text(ar ? 'EN' : 'ع'),
            ),
            IconButton(
              onPressed: openMemory,
              icon: const Icon(Icons.psychology_alt_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Chip(
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.greenAccent,
                    ),
                    label: Text('ONLINE'),
                  ),
                  Text(character, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: AnimatedBuilder(
                animation: Listenable.merge([avatarPulse, ringPulse]),
                builder: (_, __) => GestureDetector(
                  onTap: () async {
                    setState(() => state = RobotState.happy);
                    final reply = ar
                        ? 'أشعر بلمستك 😊'
                        : 'I can feel your touch 😊';
                    messages.add(ChatItem(reply, true));
                    await brain.speak(reply, language);
                    if (mounted) setState(() => state = RobotState.idle);
                  },
                  onLongPress: () {
                    setState(() => state = RobotState.thinking);
                    final reply = ar
                        ? 'أنا هنا معك 🤖❤️'
                        : 'I am here with you 🤖❤️';
                    messages.add(ChatItem(reply, true));
                    brain.speak(reply, language);
                  },
                  child: CustomPaint(
                    painter: RobotPainter(
                      t: avatarPulse.value,
                      ring: ringPulse.value,
                      state: state,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 310),
                        child: Text(
                          state == RobotState.listening
                              ? (ar ? 'أستمع إليك...' : 'Listening...')
                              : state == RobotState.thinking
                                  ? (ar ? 'أفكر...' : 'Thinking...')
                                  : state == RobotState.speaking
                                      ? (ar ? 'أتحدث...' : 'Speaking...')
                                      : (ar ? 'كيف أساعدك؟' : 'How can I help?'),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (messages.isNotEmpty)
              SizedBox(
                height: 155,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: messages.reversed.take(4).map((m) {
                    return Align(
                      alignment:
                          m.robot ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.robot
                              ? const Color(0xFF0E1B28)
                              : const Color(0xFF0B3447),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  }).toList(),
                ),
              ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF081018),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: toggleMic,
                          style: IconButton.styleFrom(
                            backgroundColor: listening
                                ? Colors.redAccent
                                : const Color(0xFF156FD2),
                          ),
                          icon: Icon(listening ? Icons.stop : Icons.mic),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TextField(
                            controller: input,
                            minLines: 1,
                            maxLines: 3,
                            onSubmitted: (_) => send(),
                            decoration: InputDecoration(
                              hintText:
                                  ar ? 'تحدث أو اكتب...' : 'Speak or type...',
                              filled: true,
                              fillColor: const Color(0xFF0C151F),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(17),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => send(),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _NavButton(Icons.camera_alt_outlined,
                              ar ? 'رؤية' : 'Vision', openCamera),
                          _NavButton(Icons.psychology_outlined,
                              ar ? 'ذاكرة' : 'Memory', openMemory),
                          _NavButton(Icons.navigation_outlined,
                              ar ? 'ملاحة' : 'Nav', openTools),
                          _NavButton(Icons.phone_android_outlined,
                              ar ? 'الهاتف' : 'Phone', openPhoneControl),
                        ],
                      ),
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

  Widget _NavButton(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.cyanAccent),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class RobotPainter extends CustomPainter {
  final double t;
  final double ring;
  final RobotState state;

  RobotPainter({required this.t, required this.ring, required this.state});

  @override
  void paint(Canvas c, Size s) {
    final x = s.width / 2;
    final bob = math.sin(t * math.pi * 2) * 5;

    c.save();
    c.translate(x, 15 + bob);

    final glow = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    c.drawCircle(const Offset(0, 170), 118, glow);

    if (state == RobotState.listening) {
      final p = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      c.drawCircle(
        const Offset(0, 85),
        125 + ring * 14,
        p,
      );
    }

    final metal = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF1F5F8),
          Color(0xFF858F98),
          Color(0xFF262D35),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(-130, 0, 260, 330));
    final dark = Paint()..color = const Color(0xFF0A1118);
    final cyan = Paint()..color = Colors.cyanAccent;

    // Body
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-87, 175, 174, 150),
        const Radius.circular(40),
      ),
      metal,
    );

    // Arms
    final arm = math.sin(t * math.pi * 2) * 8;
    c.save();
    c.translate(-112, 205);
    c.rotate(-0.05 + arm * .006);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, 0, 30, 112),
        const Radius.circular(15),
      ),
      metal,
    );
    c.restore();
    c.save();
    c.translate(112, 205);
    c.rotate(0.05 - arm * .006);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, 0, 30, 112),
        const Radius.circular(15),
      ),
      metal,
    );
    c.restore();

    // Core
    c.drawCircle(const Offset(0, 245), 28, dark);
    c.drawCircle(
      const Offset(0, 245),
      14 + math.sin(t * math.pi * 4) * 2,
      cyan,
    );

    // Neck + head
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, 140, 52, 48),
        const Radius.circular(14),
      ),
      dark,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-105, 10, 210, 132),
        const Radius.circular(48),
      ),
      metal,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-79, 31, 158, 90),
        const Radius.circular(30),
      ),
      dark,
    );

    final eyeShift = state == RobotState.thinking ? 7.0 : 0.0;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(-35 + eyeShift, 74),
        width: 34,
        height: state == RobotState.happy ? 15 : 21,
      ),
      cyan,
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(35 + eyeShift, 74),
        width: 34,
        height: state == RobotState.happy ? 15 : 21,
      ),
      cyan,
    );

    final mouth = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == RobotState.speaking ? 7 : 4
      ..strokeCap = StrokeCap.round;

    if (state == RobotState.happy) {
      final p = Path()
        ..moveTo(-25, 105)
        ..quadraticBezierTo(0, 126, 25, 105);
      c.drawPath(p, mouth);
    } else if (state == RobotState.speaking) {
      c.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 108),
          width: 29,
          height: 13 + (math.sin(t * math.pi * 10).abs() * 8),
        ),
        mouth,
      );
    } else {
      c.drawLine(const Offset(-21, 108), const Offset(21, 108), mouth);
    }

    // Legs
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-63, 318, 46, 60),
        const Radius.circular(16),
      ),
      dark,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 318, 46, 60),
        const Radius.circular(16),
      ),
      dark,
    );

    c.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPainter oldDelegate) => true;
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  const CameraPage({super.key, required this.camera});
  @override State<CameraPage> createState() => _CameraPageState();
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
            if (snap.hasError) {
              return Center(child: Text('Camera error: ${snap.error}'));
            }
            return CameraPreview(controller);
          },
        ),
      );
}

class CompassPage extends StatelessWidget {
  const CompassPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore, size: 140, color: Colors.cyanAccent),
              SizedBox(height: 16),
              Text('Compass module ready'),
              Text('Connect a device compass sensor for live heading.'),
            ],
          ),
        ),
      );
}

class WeatherDemoPage extends StatelessWidget {
  const WeatherDemoPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Weather module is included in the v2 architecture. '
              'A real provider can be enabled without placing secrets in the APK.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

class MapDemoPage extends StatelessWidget {
  const MapDemoPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Maps / turn-by-turn module is included in the v2 architecture. '
              'Google Maps requires your own Google Cloud project and API key.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
