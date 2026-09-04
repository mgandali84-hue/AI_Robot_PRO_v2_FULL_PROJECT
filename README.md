# AI Robot PRO v2

نسخة جديدة لمشروع المساعد الشخصي AI Robot PRO v2.

## الموجود في النسخة
- واجهة رئيسية مستقبلية شبيهة بالتصميم المعتمد.
- Avatar روبوت تفاعلي: عينان، فم، حالات استماع/تفكير/تحدث/فرح، حركة بسيطة.
- محادثة عربية/إنجليزية.
- Speech-to-Text عبر ميكروفون الهاتف.
- Text-to-Speech بالعربية والإنجليزية.
- ذاكرة شخصية محلية.
- كاميرا.
- واجهة Smart Home تجريبية قابلة للربط.
- شخصيات متعددة.
- اتصال اختياري بخادم AI حقيقي.

## تشغيل الذكاء الاصطناعي الحقيقي
التطبيق لا يضع مفتاح AI السري داخل APK.
يوجد خادم اختياري داخل `server/`.

شغّل الخادم:

```bash
cd server
npm install
OPENAI_API_KEY=ضع_المفتاح_هنا npm start
```

ثم ابنِ التطبيق مع عنوان الخادم:

```bash
flutter pub get
flutter build apk --release --dart-define=AI_SERVER_URL=http://YOUR_SERVER:3000
```

للهواتف عبر الإنترنت استخدم HTTPS وعنوان خادم عام.

## Codemagic
ضع المشروع في GitHub بحيث يكون:

lib/
android/
assets/
server/
pubspec.yaml
codemagic.yaml

ثم شغّل workflow:
`android-release`

## ملاحظة عن الإصدار
مجلد `android/` هنا يحتوي إعدادات Android النصية، لكن ملف `gradle-wrapper.jar` الثنائي قد يكون موجودًا أصلًا في مستودعك الحالي. لا تحذف النسخة العاملة منه. إذا كان موجودًا في مستودعك، اتركه كما هو.

## الحالة
هذه حزمة تطوير v2 وليست ملف APK بحد ذاته. الذكاء السحابي يحتاج خادمًا ومفتاح API، والربط الحقيقي للمنزل الذكي يحتاج Home Assistant/MQTT أو مزود أجهزة.

## Speech fix
Uses `listenOptions: SpeechListenOptions(...)` for current speech_to_text APIs.
