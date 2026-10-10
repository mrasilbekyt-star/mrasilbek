# 🗺️ Hudud — yugur va hududni egalla

Yugurib shahringizni egallaydigan ilova. Xarita mayda olti burchakli kataklarga (10 m) bo'lingan:

- **Yugurgan yo'lingiz sizniki bo'ladi.** Siz o'tgan har bir katak hududingizga qo'shiladi.
- **Aylanib chiqqan joyingiz ham sizniki.** Uy, bog' yoki butun mahallani aylanib, halqani yopsangiz,
  ichidagi butun maydon birdaniga hududingizga qo'shiladi.
- **Transportda hudud olinmaydi.** 25 km/soatdan tez harakat hisobga olinmaydi, GPS sakrashlari
  va noaniq o'qishlar filtrlanadi.

## Imkoniyatlar

| | Bepul | PRO |
|---|---|---|
| GPS bilan yugurish (ekran o'chiq bo'lsa ham), hudud egallash, halqalar | ✅ | ✅ |
| Vektor xarita, 3D binolar, 3D hudud, o'zbekcha ko'cha nomlari | ✅ | ✅ |
| Masofa, temp, kilometrlar, kaloriya, qadam va kadens | ✅ | ✅ |
| Ovozli murabbiy, avto-pauza, tebranish | ✅ | ✅ |
| Tarix, yutuqlar (15 ta), darajalar, hafta vazifalari | ✅ | ✅ |
| Samsung Health / Health Connect / Apple Health'ga yozish | ✅ | ✅ |
| Instagram/Telegram uchun ulashish kartasi (Neon) | ✅ | ✅ |
| Maxfiy zona (uy atrofi ulashilgan rasmlarda ko'rinmaydi) | ✅ | ✅ |
| 8 ta hudud rangi, 3 ta qo'shimcha xarita (Aurora, Tong, Sahro) | | ✅ |
| Barcha yo'llar bitta xaritada | | ✅ |
| Shaxsiy rekordlar (eng tez km, 5 km, eng katta halqa) | | ✅ |
| GPX eksport (Strava va boshqalar) | | ✅ |
| Premium ulashish kartalari (Aurora, Minimal) | | ✅ |

**Namoyish yugurish:** uydan chiqmasdan qanday ishlashini ko'rish uchun (natija saqlanmaydi).

## Test APK

Har `hudud/` ga push qilinganda GitHub o'zi APK yig'adi:
https://github.com/mrasilbekyt-star/mrasilbek/releases/tag/hudud-test

Test APK'da Pro'ni pul to'lamasdan sinab ko'rish mumkin: **Sozlamalar → Pro sinov rejimi**.

## Kompyuterda ishga tushirish

```bash
cd hudud
flutter pub get
flutter run                       # telefon USB orqali ulangan bo'lsin
flutter test                      # 35 ta test (+ node --test server/telegram-auth)
flutter build apk --release       # yoki: flutter build appbundle
```

## Xarita

Xarita **MapLibre** (vektor, GPU) bilan chiziladi. Ma'lumot **OpenFreeMap**'dan olinadi: OpenStreetMap
vektor kataklari, bepul va kalitsiz. Xarita uslublari (`lib/map/map_style.dart`) kodda yozilgan,
hudud, yo'l va yuguruvchi qatlamlari ham uslub ichida. Uslubni rasmiy validator bilan tekshirish:

```bash
flutter test tool/dump_styles_test.dart
npx --package @maplibre/maplibre-gl-style-spec gl-style-validate build/styles/night.json
```

## Login: Google va telefon raqam (tekin)

Firebase sozlanmaguncha ilova **mehmon rejimida** ishlaydi: hamma narsa bor, ma'lumotlar telefonda.

**Google orqali kirish (Firebase, tekin tarif):**
1. https://console.firebase.google.com → **Add project** → nomi `Hudud` (Google Analytics shart emas).
2. **Add app → Android**:
   - Package name: `uz.mrasilbek.hudud`
   - SHA-1 (test APK kaliti): `DD:DA:CB:7C:45:A3:D8:D6:BF:3E:89:AA:2C:3A:34:11:B9:DF:0C:01`
   - **Register app** → `google-services.json` faylini yuklab oling.
3. Faylni `hudud/android/app/google-services.json` ga qo'yib push qiling. Bu fayl maxfiy emas.
4. Firebase → **Authentication → Get started → Sign-in method → Google → Enable → Save**.

**Telefon raqam bilan (Telegram orqali, SMS'siz va tekin):** `server/telegram-auth/README.md`.

Test APK'lar git'dagi `android/app/hudud-test.keystore` test kaliti bilan imzolanadi. Shuning uchun
SHA-1 doim bir xil. Play Market uchun alohida maxfiy kalit (`key.properties`) ishlatiladi. Uning va
Play App Signing'ning SHA-1'larini ham Firebase'ga qo'shish kerak.

## Pro obunasi (Google Play)

1. Play Console → **Monetize → Subscriptions**: `hudud_pro_monthly` va `hudud_pro_yearly` obunalarini
   yarating, narxini qo'ying.
2. Ilova Play'dan (yoki ichki test trekidan) o'rnatilganda obuna oynasi narxlarni ko'rsatadi.
3. Obuna bekor qilinsa, ilova keyingi ochilishda Pro'ni o'zi o'chiradi.

## Play Market'ga joylashdan oldin

- **Imzo kaliti:** `android/key.properties` (Steady Doc'dagidek, `README` 2-bo'lim). U git'ga yuklanmaydi.
- **Joylashuv:** Play Console'da "Location permissions" va "Foreground service: location" deklaratsiyasini
  to'ldiring (yugurish paytida GPS yozish uchun), qisqa video talab qilinadi.
- **Health Connect:** "Health apps" deklaratsiyasi (faqat yozish: mashg'ulot, masofa, kaloriya).
- **Maxfiylik siyosati:** joylashuv faqat telefonda saqlanadi, serverga yuborilmaydi.

## Loyiha tuzilishi

| Papka | Nima bor |
|---|---|
| `lib/core/` | Hudud mexanikasi: proyeksiya, olti burchakli kataklar, GPS filtri, halqa topish, chegaralar |
| `lib/run/` | GPS manbalari (telefon, namoyish) va yugurish sessiyasi |
| `lib/data/` | Yugurishlarni saqlash, sozlamalar, statistika, yutuqlar |
| `lib/map/` | Xarita uslublari, GeoJSON, xarita vidjeti |
| `lib/services/` | Pro obunasi, ovozli murabbiy, Health Connect va qadamlar, GPX |
| `lib/ui/` | Ekranlar |
| `lib/l10n/strings.dart` | Barcha matnlar 3 tilda |
