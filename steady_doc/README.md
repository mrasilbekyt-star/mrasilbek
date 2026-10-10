# 🩺 Steady Doc — S Pen uchun operatsiya o'yini

Bemorlar g'alati narsalarni yutib yuborgan: o'yinchoq mashina, baliq, kalit, burger va hokazo.
O'yinchi ularni operatsiya qilib chiqarib oladi. O'yin Samsung **S Pen** uchun moslangan,
lekin barmoq bilan ham bemalol o'ynaladi.

## O'yinda nimalar bor

- **12 ta bemor**, har biri oldingisidan qiyinroq.
- **5 bosqich:** 💉 ukol → 🩻 rentgen → 🔪 kesish → 🥢 chiqarish → 🧵 tikish.
- **Yurak monitori:** har bir xato yurak urishini tezlashtiradi. 170 BPM ga yetsa, bemor hushidan ketadi.
- **Yulduzlar:** 0–1 xato bo'lsa 3 ta, 2–4 xato bo'lsa 2 ta, undan ko'p bo'lsa 1 ta yulduz.
  Keyingi bemor oldingisi davolangandan keyin ochiladi.
- **S Pen imkoniyatlari:**
  - *bosim kuchi:* qattiq bosilsa "Juda chuqur!" yoki "Juda qattiq!" xatosi chiqadi;
  - *hover:* ruchkani ekranga tegizmasdan rentgen qilish va asbobni nishonga olish;
  - *kaftni sezmaslik:* ruchka ishlatilayotganda ekranga tekkan kaft hisobga olinmaydi.
- **3 til:** o'zbek, ingliz va rus (telefon tiliga qarab o'zi tanlanadi).
- Ovozlar va vibratsiya bor, natijalar telefonda saqlanadi, internet kerak emas.

## Kompyuterda ishga tushirish

Flutter o'rnatilgan bo'lishi kerak (Spoortza uchun o'rnatgansiz). Flutter 3.41 yoki undan yangisi kerak.

```bash
cd steady_doc
flutter pub get
flutter run          # telefon USB orqali ulangan bo'lsin (USB debugging yoqilgan)
flutter test         # 91 ta test
```

## Play Market'ga joylash

### 1. Ilova ID

Hozirgi ID: `uz.mrasilbek.steady_doc`. Uni o'zgartirmoqchi bo'lsangiz, **birinchi yuklashdan oldin**
`android/app/build.gradle.kts` ichidagi `applicationId` qatorini o'zgartiring. Yuklagandan keyin
ID'ni o'zgartirib bo'lmaydi.

### 2. Imzo kaliti

Bu ish bir marta qilinadi. Kalitni yarating:

```bash
keytool -genkey -v -keystore C:/Users/asilb/steady-doc-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keyin `steady_doc/android/key.properties` faylini yarating:

```properties
storePassword=PAROLINGIZ
keyPassword=PAROLINGIZ
keyAlias=upload
storeFile=C:/Users/asilb/steady-doc-upload.jks
```

⚠️ `.jks` fayl va `key.properties` GitHub'ga yuklanmaydi (`.gitignore`'da bor). Ularning nusxasini
xavfsiz joyda saqlang: kalit yo'qolsa, yangilanish chiqarish qiyinlashadi.

### 3. AAB yig'ish

```bash
flutter build appbundle
```

Tayyor fayl: `build/app/outputs/bundle/release/app-release.aab`.

### 4. Play Console

1. **Create app** → nomi *Steady Doc*, turi *Game*, *Free*.
2. **Store listing:** matnlar `store/listing.md`'da 3 tilda tayyor. Ikonka `store/icon_512.png`,
   feature graphic `store/feature_graphic.png`. Skrinshotlarni telefoningizdan oling.
3. **Privacy policy:** `store/privacy_policy.md`'ga email manzilingizni yozing va uni internetga
   joylang (masalan GitHub Pages yoki Spoortza sayti). Havolasini Play Console'ga qo'ying.
4. **Data safety:** o'yin hech qanday ma'lumot yig'maydi va internetga ulanmaydi, shuning uchun
   "No data collected" deb belgilang.
5. **Target audience:** 13+ ni tanlang. Bolalar uchun deb belgilasangiz, Google'ning qattiqroq
   qoidalari qo'llanadi.
6. **Content rating:** savollarga halol javob bering.
7. Shaxsiy dasturchi akkaunti bo'lsa, Google avval **yopiq test** talab qiladi:
   kamida 12 tester, 14 kun. Spoortza'da bu jarayondan o'tgansiz.

**Galaxy Store** (ixtiyoriy): seller.samsungapps.com orqali o'sha AAB faylni yuklasa bo'ladi.
U yerda raqobat kamroq va S Pen o'yinlari ko'proq ko'rinadi.

## Loyiha tuzilishi

| Papka | Nima bor |
|---|---|
| `lib/game/` | O'yin mantiqi: darajalar, bosqichlar, yurak urishi. Ekrandan mustaqil, testlar shu yerni tekshiradi |
| `lib/painting/` | Grafika: bemor, rentgen, shprits, yo'laklar, choklar (hammasi kod bilan chiziladi) |
| `lib/ui/` | Ekranlar: bosh menyu, bemorlar ro'yxati, o'yin, sozlamalar |
| `lib/l10n/strings.dart` | Barcha matnlar 3 tilda |
| `assets/sfx/` | Ovozlar. Ular `tool/gen_sfx.py` bilan yaratiladi, begona audio ishlatilmagan |
| `tool/render_store_assets_test.dart` | Ikonka va Play Market rasmlarini qayta chizadi: `flutter test tool/render_store_assets_test.dart` |
| `store/` | Play Market uchun rasmlar, matnlar va maxfiylik siyosati |

O'yin maydoni 1000 × 1400 o'lchamli "dizayn" koordinatalarida joylashgan va har qanday ekranga
moslab kattalashtiriladi, shuning uchun tezlik va aniqlik har bir telefonda bir xil ishlaydi.

## Keyingi qadamlar

- Real (fotorealistik) grafika
- AdMob: mukofotli reklama orqali "qo'shimcha hayot"
- Yangi bemorlar va asbob skinlari
- Fon musiqasi
