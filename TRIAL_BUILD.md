# AI Robot PRO v2 — Trial

## الهدف
نسخة تجريبية للمساعد الشخصي بدون تسجيل دخول إلزامي.

## تشغيل
flutter pub get
flutter analyze
flutter build apk --release

## النتيجة
build/app/outputs/flutter-apk/app-release.apk

## ملاحظات
- تسجيل الدخول غير إجباري في هذه النسخة.
- الذاكرة محلية.
- Phone Control اختياري ويحتاج تفعيل Android Accessibility يدويًا.
- Google Maps الحقيقي يحتاج Google Cloud project + API key.
- الذكاء السحابي الحقيقي يحتاج خادمًا/مزود AI؛ لا نضع المفتاح السري داخل APK.
