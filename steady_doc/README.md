# 🩺 Steady Doc — S Pen uchun jarrohlik simulyatori

Kattalar uchun real jarrohlik o'yini. Bemorlar tanga, batareya, magnit, tish protezi kabi narsalarni
yutib yuborgan yoki o'tida tosh paydo bo'lgan; o'yinchi jarroh sifatida ularni operatsiya qiladi.
O'yin Samsung **S Pen** uchun moslangan, lekin barmoq bilan ham bemalol o'ynaladi.

## O'yinda nimalar bor

- **12 ta bemor**, har biri oldingisidan qiyinroq.
- **5 bosqich:** 💉 ukol → 🩻 rentgen → 🔪 kesish → 🥢 chiqarish → 🧵 tikish.
- **Bemor monitori:** EKG, yurak urishi, SpO2 va qon bosimi. Har bir xato bemor stressini oshiradi,
  monitor "XAVF" signalini beradi. Yurak urishi 170 ga yetsa, bemor hushidan ketadi.
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
5. **Target audience:** 18+ yoki 16+ ni tanlang (o'yin kattalar uchun).
6. **Content rating:** jarrohlik va qon tasvirlari borligini halol belgilang (taxminan 16+ chiqadi).
7. Shaxsiy dasturchi akkaunti bo'lsa, Google avval **yopiq test** talab qiladi:
   kamida 12 tester, 14 kun. Spoortza'da bu jarayondan o'tgansiz.

**Galaxy Store** (ixtiyoriy): seller.samsungapps.com orqali o'sha AAB faylni yuklasa bo'ladi.
U yerda raqobat kamroq va S Pen o'yinlari ko'proq ko'rinadi.

## Real grafika (`assets/art/`)

O'yin sahnasi hozircha kod bilan chiziladi. `assets/art/` papkasiga quyidagi PNG fayllarni qo'ysangiz,
o'yin ularni avtomatik ishlata boshlaydi. Qaysi fayl bo'lmasa, o'rniga chizilgan grafika chiqadi.

| Fayl | Nima |
|---|---|
| `scene_closed.png` | Bemor tepadan, qorin ochiq, qolgan joy yashil mato bilan yopilgan |
| `scene_open.png` | Xuddi shu kadr, qorin ochilgan (organlar ko'rinadi) |
| `scene_xray.png` | Xuddi shu kadrning rentgen surati |
| `tool_forceps.png` | Pinset (foni shaffof, uchi pastda) |
| `obj_<nom>.png` | Chiqariladigan narsa, masalan `obj_coin.png`. Nomlar: `lib/game/levels.dart` → `findingEmoji` |

Sahna rasmlari tik (3:4) bo'lishi kerak. Ular 1000 × 1400 maydonni to'liq qoplaydi.
Rasm qo'yilgandan keyin kesik, yo'lak va chiqish nuqtalarining joyini rasmga moslash kerak bo'ladi
(`lib/game/levels.dart` → `BodyLayout`).

## Loyiha tuzilishi

| Papka | Nima bor |
|---|---|
| `lib/game/` | O'yin mantiqi: darajalar, bosqichlar, yurak urishi. Ekrandan mustaqil, testlar shu yerni tekshiradi |
| `lib/painting/` | Grafika: sahna, rentgen, shprits, skalpel, pinset, choklar; `art.dart` real rasmlarni yuklaydi |
| `lib/ui/` | Ekranlar: bosh menyu, bemorlar ro'yxati, o'yin, sozlamalar |
| `lib/l10n/strings.dart` | Barcha matnlar 3 tilda |
| `assets/sfx/` | Ovozlar. Ular `tool/gen_sfx.py` bilan yaratiladi, begona audio ishlatilmagan |
| `tool/render_store_assets_test.dart` | Ikonka va Play Market rasmlarini qayta chizadi: `flutter test tool/render_store_assets_test.dart` |
| `store/` | Play Market uchun rasmlar, matnlar va maxfiylik siyosati |

O'yin maydoni 1000 × 1400 o'lchamli "dizayn" koordinatalarida joylashgan va har qanday ekranga
moslab kattalashtiriladi, shuning uchun tezlik va aniqlik har bir telefonda bir xil ishlaydi.

## Keyingi qadamlar

- `assets/art/` uchun real rasmlar (Gemini yoki 3D)
- AdMob: mukofotli reklama orqali "qo'shimcha hayot"
- Yangi bemorlar va asbob skinlari
- Fon musiqasi
