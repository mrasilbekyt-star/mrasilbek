/// Every text in the app, in Uzbek, English and Russian.
class Strings {
  const Strings(this.lang);

  final String lang;

  static const supported = ['uz', 'en', 'ru'];

  static const languageNames = {
    'uz': "O'zbekcha",
    'en': 'English',
    'ru': 'Русский',
  };

  String _t(String uz, String en, String ru) => switch (lang) {
        'uz' => uz,
        'ru' => ru,
        _ => en,
      };

  /// The TTS voice for this language.
  String get speechLocale => switch (lang) {
        'uz' => 'uz-UZ',
        'ru' => 'ru-RU',
        _ => 'en-US',
      };

  // ------------------------------------------------------------------ common

  String get appName => 'Hudud';
  String get tagline => _t('Yugur. Aylan. Egalla.', 'Run. Circle. Claim.', 'Беги. Окружай. Захватывай.');
  String get start => _t('BOSHLASH', 'START', 'СТАРТ');
  String get cancel => _t('Bekor qilish', 'Cancel', 'Отмена');
  String get ok => _t('Tushunarli', 'Got it', 'Понятно');
  String get yes => _t('Ha', 'Yes', 'Да');
  String get no => _t("Yo'q", 'No', 'Нет');
  String get done => _t('Tayyor', 'Done', 'Готово');
  String get close => _t('Yopish', 'Close', 'Закрыть');
  String get next => _t('Keyingi', 'Next', 'Далее');
  String get settings => _t('Sozlamalar', 'Settings', 'Настройки');
  String get history => _t('Tarix', 'History', 'История');
  String get profile => _t('Profil', 'Profile', 'Профиль');
  String get share => _t('Ulashish', 'Share', 'Поделиться');

  // ------------------------------------------------------------------ units

  String km(double meters) => '${_num(meters / 1000, 2)} km';

  String area(double m2) => m2 < 10000
      ? '${m2.round()} m²'
      : _t('${_num(m2 / 10000, 2)} ga', '${_num(m2 / 10000, 2)} ha', '${_num(m2 / 10000, 2)} га');

  String areaShort(double m2) => m2 < 10000 ? '${m2.round()}' : _num(m2 / 10000, 2);
  String areaUnit(double m2) => m2 < 10000 ? 'm²' : _t('ga', 'ha', 'га');

  String _num(double v, int digits) {
    final s = v.toStringAsFixed(digits);
    return lang == 'en' ? s : s.replaceAll('.', ',');
  }

  String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// "5'12"" per kilometer.
  String pace(double? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm > 3600) return "–'––\"";
    final s = secondsPerKm.round();
    return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"";
  }

  String get perKm => _t('/km', '/km', '/км');
  String get kcal => _t('kkal', 'kcal', 'ккал');

  String date(DateTime d) {
    const uz = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const ru = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final month = _t(uz[d.month - 1], en[d.month - 1], ru[d.month - 1]);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return lang == 'en' ? '$month ${d.day}, $time' : '${d.day} $month, $time';
  }

  // ------------------------------------------------------------------ home

  String get yourTerritory => _t('Sizning hududingiz', 'Your territory', 'Ваша территория');
  String runsCount(int n) => _t('$n yugurish', n == 1 ? '1 run' : '$n runs', '$n ${_ruPlural(n, 'пробежка', 'пробежки', 'пробежек')}');
  String streakDays(int n) => _t('$n kun', n == 1 ? '1 day' : '$n days', '$n ${_ruPlural(n, 'день', 'дня', 'дней')}');
  String get gpsSearching => _t('GPS qidirilmoqda…', 'Finding GPS…', 'Поиск GPS…');
  String get gpsReady => _t('GPS tayyor', 'GPS ready', 'GPS готов');
  String get gpsWeak => _t('GPS signali kuchsiz', 'Weak GPS signal', 'Слабый сигнал GPS');
  String get emptyTerritory => _t(
        "Hali hududingiz yo'q. Yugurishni boshlang: yo'lingiz sizniki bo'ladi, biror joyni aylanib chiqsangiz, ichi ham sizniki.",
        'No territory yet. Start a run: your path becomes yours, and anything you run around is yours too.',
        'Территории пока нет. Начните пробежку: ваш путь станет вашим, а всё, что вы обежите, тоже.',
      );

  // ------------------------------------------------------------------ run

  String get time => _t('Vaqt', 'Time', 'Время');
  String get distance => _t('Masofa', 'Distance', 'Дистанция');
  String get paceLabel => _t('Temp', 'Pace', 'Темп');
  String get newLand => _t('Yangi hudud', 'New land', 'Новая земля');
  String get loopsLabel => _t('Halqalar', 'Loops', 'Петли');
  String get steps => _t('Qadam', 'Steps', 'Шаги');
  String get cadence => _t('Kadens', 'Cadence', 'Каденс');
  String get calories => _t('Kaloriya', 'Calories', 'Калории');
  String get pause => _t('Pauza', 'Pause', 'Пауза');
  String get resume => _t('Davom etish', 'Resume', 'Продолжить');
  String get holdToFinish => _t('Tugatish uchun bosib turing', 'Hold to finish', 'Удерживайте, чтобы завершить');
  String get paused => _t('PAUZA', 'PAUSED', 'ПАУЗА');
  String get autoPaused => _t('AVTO-PAUZA', 'AUTO-PAUSED', 'АВТОПАУЗА');
  String get demoBadge => _t('NAMOYISH', 'DEMO', 'ДЕМО');
  String closeLoop(int meters) => _t('Halqani yoping: $meters m', 'Close the loop: $meters m', 'Замкните петлю: $meters м');
  String get tooFast => _t(
        'Juda tez: transportda hudud olinmaydi',
        'Too fast: no land is claimed from a vehicle',
        'Слишком быстро: на транспорте земля не засчитывается',
      );
  String get landClaimed => _t('HUDUD EGALLANDI!', 'LAND CLAIMED!', 'ЗЕМЛЯ ЗАХВАЧЕНА!');
  String get leaveRunTitle => _t('Yugurishni bekor qilasizmi?', 'Discard this run?', 'Отменить пробежку?');
  String get leaveRunText => _t(
        "Bu yugurish saqlanmaydi va hudud qo'shilmaydi.",
        'This run will not be saved and no land will be added.',
        'Пробежка не сохранится, и земля не будет добавлена.',
      );
  String get notificationTitle => _t('Hudud: yugurish davom etmoqda', 'Hudud: run in progress', 'Hudud: идёт пробежка');
  String get notificationText => _t(
        "Yo'lingiz va hududingiz yozib borilmoqda",
        'Recording your route and territory',
        'Записываем маршрут и территорию',
      );

  // ------------------------------------------------------------------ permissions

  String get locationNeededTitle => _t('Joylashuv kerak', 'Location needed', 'Нужна геолокация');
  String get locationNeeded => _t(
        "Hudud egallash uchun ilova yugurish paytida joylashuvingizni bilishi kerak. Ekran o'chiq bo'lsa ham yozib borish uchun bildirishnoma ko'rinib turadi.",
        'To claim land the app needs your location while you run. A notification keeps recording while the screen is off.',
        'Чтобы захватывать землю, приложению нужна геолокация во время пробежки. Уведомление продолжает запись при выключенном экране.',
      );
  String get locationOff => _t(
        "Telefonda joylashuv (GPS) o'chiq. Uni yoqib, qayta urinib ko'ring.",
        'Location (GPS) is off on the phone. Turn it on and try again.',
        'Геолокация (GPS) выключена. Включите её и попробуйте снова.',
      );
  String get locationDeniedForever => _t(
        'Joylashuvga ruxsat berilmagan. Sozlamalarda Hudud uchun joylashuvni yoqing.',
        'Location permission is off. Allow location for Hudud in the phone settings.',
        'Доступ к геолокации запрещён. Разрешите его для Hudud в настройках телефона.',
      );
  String get openSettings => _t('Sozlamalarni ochish', 'Open settings', 'Открыть настройки');
  String get allow => _t('Ruxsat berish', 'Allow', 'Разрешить');

  // ------------------------------------------------------------------ summary

  String get greatRun => _t('Zo\'r yugurish!', 'Great run!', 'Отличная пробежка!');
  String get demoNotSaved => _t(
        'Bu namoyish edi: natija saqlanmaydi. Endi haqiqiy yugurishga chiqing!',
        'This was a demo and is not saved. Now go for a real run!',
        'Это было демо, результат не сохранён. Теперь — настоящая пробежка!',
      );
  String get saved => _t('Saqlandi', 'Saved', 'Сохранено');
  String get savedToHealth => _t('Sog\'liq ilovasiga yozildi', 'Saved to your health app', 'Записано в приложение здоровья');
  String get splits => _t('Kilometrlar', 'Splits', 'Отрезки');
  String kmNumber(int n) => _t('$n-km', 'Km $n', '$n-й км');
  String get newBadges => _t('Yangi yutuqlar', 'New badges', 'Новые награды');
  String get nothingRun => _t(
        'Masofa juda qisqa, yugurish saqlanmadi.',
        'Too short to save.',
        'Слишком коротко, пробежка не сохранена.',
      );

  // ------------------------------------------------------------------ history

  String get noRuns => _t(
        "Hali yugurish yo'q. Birinchisini boshlang!",
        'No runs yet. Start your first one!',
        'Пробежек пока нет. Начните первую!',
      );
  String get allRoutes => _t("Barcha yo'llarim", 'All my routes', 'Все мои маршруты');
  String get thisMonth => _t('Shu oy', 'This month', 'В этом месяце');

  // ------------------------------------------------------------------ profile

  String get rankLabel => _t('Daraja', 'Rank', 'Ранг');
  String rankName(int r) => switch (r) {
        0 => _t('Boshlovchi', 'Rookie', 'Новичок'),
        1 => _t("Ko'cha qo'riqchisi", 'Street keeper', 'Хранитель улицы'),
        2 => _t('Mahalla posboni', 'Mahalla guard', 'Страж махалли'),
        3 => _t('Mahalla sardori', 'Mahalla captain', 'Капитан махалли'),
        4 => _t('Tuman qahramoni', 'District hero', 'Герой района'),
        5 => _t('Shahar afsonasi', 'City legend', 'Легенда города'),
        _ => _t('Hudud imperatori', 'Land emperor', 'Император земель'),
      };
  String xpToNext(int xp) => _t('Keyingi darajagacha $xp XP', '$xp XP to next rank', 'До следующего ранга $xp XP');
  String get totals => _t('Jami', 'Totals', 'Всего');
  String get totalDistance => _t('Jami masofa', 'Total distance', 'Всего км');
  String get totalTime => _t('Jami vaqt', 'Total time', 'Всего времени');
  String get bestStreak => _t('Eng uzun seriya', 'Best streak', 'Лучшая серия');
  String get currentStreak => _t('Joriy seriya', 'Current streak', 'Текущая серия');
  String get weeklyMissions => _t('Hafta vazifalari', 'This week', 'Задания недели');
  String missionTitle(String id) => switch (id) {
        'week_km' => _t('10 km yuguring', 'Run 10 km', 'Пробегите 10 км'),
        'week_area' => _t('0,5 ga yangi hudud', 'Claim 0.5 ha', 'Захватите 0,5 га'),
        _ => _t('3 ta halqa yoping', 'Close 3 loops', 'Замкните 3 петли'),
      };
  String get achievements => _t('Yutuqlar', 'Badges', 'Награды');
  String achievementTitle(String id) => switch (id) {
        'first_run' => _t('Birinchi qadam', 'First step', 'Первый шаг'),
        'first_loop' => _t('Birinchi halqa', 'First loop', 'Первая петля'),
        'area_1ha' => _t('1 gektar', 'One hectare', 'Один гектар'),
        'km_5' => _t('5 km', '5 km', '5 км'),
        'streak_3' => _t('3 kun ketma-ket', '3-day streak', '3 дня подряд'),
        'early' => _t('Tong otguncha', 'Before sunrise', 'До рассвета'),
        'km_10' => _t('10 km', '10 km', '10 км'),
        'big_loop' => _t('Katta halqa', 'Big loop', 'Большая петля'),
        'area_10ha' => _t('Mahalla egasi', 'Mahalla owner', 'Хозяин махалли'),
        'streak_7' => _t('Bir hafta', 'Full week', 'Целая неделя'),
        'loops_25' => _t('Halqa ustasi', 'Loop master', 'Мастер петель'),
        'total_100' => _t('100 km', '100 km', '100 км'),
        'half' => _t('Yarim marafon', 'Half marathon', 'Полумарафон'),
        'streak_30' => _t('Bir oy', 'Full month', 'Целый месяц'),
        _ => _t('Hudud qiroli', 'Land king', 'Король земель'),
      };
  String achievementText(String id) => switch (id) {
        'first_run' => _t('Birinchi yugurishni tugating', 'Finish your first run', 'Завершите первую пробежку'),
        'first_loop' => _t('Biror joyni aylanib, halqani yoping', 'Run around something and close a loop', 'Обегите что-нибудь и замкните петлю'),
        'area_1ha' => _t('1 ga hududga ega bo\'ling', 'Own 1 ha of land', 'Владейте 1 га'),
        'km_5' => _t('Bir yugurishda 5 km', '5 km in one run', '5 км за пробежку'),
        'streak_3' => _t('3 kun ketma-ket yuguring', 'Run 3 days in a row', 'Бегайте 3 дня подряд'),
        'early' => _t('Soat 7 dan oldin yuguring', 'Run before 7 am', 'Пробежка до 7 утра'),
        'km_10' => _t('Bir yugurishda 10 km', '10 km in one run', '10 км за пробежку'),
        'big_loop' => _t('5 ga lik halqa yoping', 'Close a 5 ha loop', 'Замкните петлю на 5 га'),
        'area_10ha' => _t('10 ga hududga ega bo\'ling', 'Own 10 ha', 'Владейте 10 га'),
        'streak_7' => _t('7 kun ketma-ket yuguring', 'Run 7 days in a row', 'Бегайте 7 дней подряд'),
        'loops_25' => _t('25 ta halqa yoping', 'Close 25 loops', 'Замкните 25 петель'),
        'total_100' => _t('Jami 100 km yuguring', 'Run 100 km in total', 'Пробегите 100 км всего'),
        'half' => _t('Bir yugurishda 21,1 km', '21.1 km in one run', '21,1 км за пробежку'),
        'streak_30' => _t('30 kun ketma-ket yuguring', 'Run 30 days in a row', 'Бегайте 30 дней подряд'),
        _ => _t('1 km² hududga ega bo\'ling', 'Own 1 km² of land', 'Владейте 1 км²'),
      };
  String get records => _t('Shaxsiy rekordlar', 'Personal records', 'Личные рекорды');
  String get fastestKm => _t('Eng tez 1 km', 'Fastest 1 km', 'Быстрейший 1 км');
  String get fastest5k => _t('Eng tez 5 km', 'Fastest 5 km', 'Быстрейшие 5 км');
  String get longestRun => _t('Eng uzun yugurish', 'Longest run', 'Самая длинная');
  String get biggestLoop => _t('Eng katta halqa', 'Biggest loop', 'Самая большая петля');
  String get mostLand => _t("Bir yugurishda eng ko'p hudud", 'Most land in a run', 'Больше всего земли за раз');

  // ------------------------------------------------------------------ settings

  String get language => _t('Til', 'Language', 'Язык');
  String get territoryColor => _t('Hudud rangi', 'Territory color', 'Цвет территории');
  String get mapStyle => _t('Xarita uslubi', 'Map style', 'Стиль карты');
  String mapThemeName(String id) => switch (id) {
        'night' => _t('Tun', 'Night', 'Ночь'),
        'aurora' => _t('Aurora', 'Aurora', 'Аврора'),
        'dawn' => _t('Tong', 'Dawn', 'Рассвет'),
        _ => _t('Sahro', 'Desert', 'Пустыня'),
      };
  String get voiceCoach => _t('Ovozli murabbiy', 'Voice coach', 'Голосовой тренер');
  String get voiceCoachText => _t(
        'Har kilometr, temp va egallangan hududni aytib boradi',
        'Announces each kilometer, your pace and land you claim',
        'Объявляет каждый километр, темп и захваченную землю',
      );
  String get autoPause => _t('Avto-pauza', 'Auto-pause', 'Автопауза');
  String get autoPauseText => _t(
        "To'xtasangiz vaqt to'xtaydi, yursangiz davom etadi",
        'Stops the clock when you stop, resumes when you move',
        'Останавливает время, когда вы стоите',
      );
  String get vibration => _t('Tebranish', 'Vibration', 'Вибрация');
  String get weight => _t('Vazn (kaloriya uchun)', 'Weight (for calories)', 'Вес (для калорий)');
  String get healthSync => _t('Sog\'liq ilovasi', 'Health app', 'Приложение здоровья');
  String get healthSyncText => _t(
        'Yugurishlarni Samsung Health / Health Connect ga ham yozish',
        'Also save runs to Samsung Health / Health Connect',
        'Записывать пробежки в Samsung Health / Health Connect',
      );
  String get healthSyncTextIos => _t(
        'Yugurishlarni Apple Health ga ham yozish',
        'Also save runs to Apple Health',
        'Записывать пробежки в Apple Health',
      );
  String get healthConnectMissing => _t(
        "Buning uchun Health Connect ilovasi kerak. Uni o'rnatasizmi?",
        'This needs the Health Connect app. Install it?',
        'Для этого нужно приложение Health Connect. Установить?',
      );
  String get install => _t("O'rnatish", 'Install', 'Установить');
  String get privacyZone => _t('Maxfiy zona (uyingiz)', 'Privacy zone (home)', 'Приватная зона (дом)');
  String get privacyZoneText => _t(
        "Ulashilgan rasmlarda uyingiz atrofidagi 250 m yo'l ko'rinmaydi",
        'Shared images hide your route within 250 m of home',
        'На картинках скрыт маршрут в радиусе 250 м от дома',
      );
  String get setHomeHere => _t('Shu yerni uy deb belgilash', 'Set home here', 'Отметить дом здесь');
  String get homeSet => _t('Belgilangan', 'Set', 'Отмечено');
  String get clearHome => _t("O'chirish", 'Clear', 'Убрать');
  String get demoRun => _t('Namoyish yugurish', 'Demo run', 'Демо-пробежка');
  String get demoRunText => _t(
        "Uydan chiqmay qanday ishlashini ko'ring (saqlanmaydi)",
        'See how it works without going out (not saved)',
        'Посмотрите, как это работает, не выходя (не сохраняется)',
      );
  String get exportGpx => _t('GPX eksport', 'Export GPX', 'Экспорт GPX');
  String get exportGpxText => _t(
        "Barcha yo'llarni Strava va boshqa ilovalar uchun fayl qilib olish",
        'All routes as a file for Strava and other apps',
        'Все маршруты файлом для Strava и других',
      );
  String get resetData => _t("Barcha ma'lumotlarni o'chirish", 'Erase all data', 'Удалить все данные');
  String get resetConfirm => _t(
        "Barcha yugurishlar va hudud o'chadi. Ishonchingiz komilmi?",
        'All runs and territory will be erased. Are you sure?',
        'Все пробежки и территория будут удалены. Вы уверены?',
      );
  String get about => _t('Ilova haqida', 'About', 'О приложении');
  String get mapCredits => _t(
        'Xarita: OpenFreeMap, © OpenMapTiles, © OpenStreetMap hissadorlari',
        'Map: OpenFreeMap, © OpenMapTiles, © OpenStreetMap contributors',
        'Карта: OpenFreeMap, © OpenMapTiles, © участники OpenStreetMap',
      );
  String get proPreview => _t('Pro sinov rejimi', 'Pro preview', 'Тест Pro');

  // ------------------------------------------------------------------ pro

  String get pro => 'PRO';
  String get proTitle => 'Hudud PRO';
  String get proSubtitle => _t(
        "Hududingizni o'zingizga xos qiling va har bir yugurishdan ko'proq oling",
        'Make your land your own and get more from every run',
        'Сделайте территорию своей и получайте больше от каждой пробежки',
      );
  String get proSkins => _t('8 ta hudud rangi va 3 ta maxsus xarita', '8 territory colors and 3 extra map styles', '8 цветов территории и 3 стиля карты');
  String get proHeatmap => _t("Barcha yo'llaringiz bitta xaritada", 'All your routes on one map', 'Все маршруты на одной карте');
  String get proRecords => _t('Shaxsiy rekordlar va chuqur statistika', 'Personal records and deeper stats', 'Личные рекорды и подробная статистика');
  String get proGpx => _t('GPX eksport (Strava va boshqalar)', 'GPX export (Strava and more)', 'Экспорт GPX (Strava и др.)');
  String get proCards => _t('Premium ulashish kartalari', 'Premium share cards', 'Премиум-карточки для соцсетей');
  String get proSoon => _t(
        'Tez kunda: hudud qalqoni, klanlar va mahalla reytingi',
        'Coming soon: land shield, clans and mahalla leaderboards',
        'Скоро: щит территории, кланы и рейтинг махаллей',
      );
  String get perMonth => _t('oyiga', 'per month', 'в месяц');
  String get perYear => _t('yiliga', 'per year', 'в год');
  String get bestValue => _t('ENG FOYDALI', 'BEST VALUE', 'ВЫГОДНЕЕ');
  String get subscribe => _t('Obuna bo\'lish', 'Subscribe', 'Подписаться');
  String get restore => _t('Xaridni tiklash', 'Restore purchase', 'Восстановить покупку');
  String get youArePro => _t('Siz Hudud PRO a\'zosisiz', 'You are Hudud PRO', 'У вас Hudud PRO');
  String get storeUnavailable => _t(
        "Obuna hozircha mavjud emas. U ilova Google Play'dan o'rnatilganda ishlaydi.",
        'Subscriptions are not available yet. They work when the app is installed from Google Play.',
        'Подписка пока недоступна. Она работает, когда приложение установлено из Google Play.',
      );
  String get subscriptionTerms => _t(
        "Obuna har davrda avtomatik yangilanadi. Uni istalgan payt Google Play → Obunalar bo'limida bekor qilish mumkin.",
        'The subscription renews automatically. Cancel any time in Google Play → Subscriptions.',
        'Подписка продлевается автоматически. Отменить можно в Google Play → Подписки.',
      );
  String get proOnly => _t('Bu Hudud PRO uchun', 'This is part of Hudud PRO', 'Это функция Hudud PRO');

  // ------------------------------------------------------------------ onboarding

  String get onboardTitle1 => _t('Yuguring', 'Run', 'Бегите');
  String get onboardText1 => _t(
        "Har bir yugurgan ko'changiz xaritada sizniki bo'lib boradi.",
        'Every street you run becomes yours on the map.',
        'Каждая улица, по которой вы бежите, становится вашей.',
      );
  String get onboardTitle2 => _t('Aylanib chiqing', 'Circle around', 'Окружайте');
  String get onboardText2 => _t(
        "Uyingiz, bog' yoki butun mahallani aylanib, halqani yopsangiz, ichidagi hamma joy sizniki.",
        'Run around your block, a park or the whole mahalla and close the loop: everything inside is yours.',
        'Обегите квартал, парк или всю махаллю и замкните петлю — всё внутри ваше.',
      );
  String get onboardTitle3 => _t('Kengaytiring', 'Grow', 'Расширяйтесь');
  String get onboardText3 => _t(
        "Har kuni yuguring, yutuqlar yig'ing va hududingizni shahar bo'ylab kengaytiring.",
        'Run every day, earn badges and grow your land across the city.',
        'Бегайте каждый день, собирайте награды и расширяйте землю по городу.',
      );
  String get letsGo => _t('Boshladik!', "Let's go!", 'Поехали!');

  // ------------------------------------------------------------------ voice coach

  String get sayStart => _t('Yugurish boshlandi. Omad!', 'Run started. Good luck!', 'Пробежка началась. Удачи!');
  String get sayPaused => _t('Pauza', 'Paused', 'Пауза');
  String get sayResumed => _t('Davom etamiz', 'Resumed', 'Продолжаем');
  String sayKm(int km, Duration total, double? pace) {
    final p = pace?.round();
    final paceText = p == null
        ? ''
        : _t(' Temp: ${p ~/ 60} daqiqa ${p % 60} soniya.', ' Pace: ${p ~/ 60} minutes ${p % 60} seconds.',
            ' Темп: ${p ~/ 60} минут ${p % 60} секунд.');
    return _t('$km kilometr. Vaqt: ${_spokenDuration(total)}.$paceText',
        '$km kilometers. Time: ${_spokenDuration(total)}.$paceText',
        '$km ${_ruPlural(km, 'километр', 'километра', 'километров')}. Время: ${_spokenDuration(total)}.$paceText');
  }

  String sayClaimed(double m2) => _t(
        'Hudud egallandi! Plyus ${_spokenArea(m2)}.',
        'Land claimed! Plus ${_spokenArea(m2)}.',
        'Земля захвачена! Плюс ${_spokenArea(m2)}.',
      );
  String sayCloseLoop(int meters) => _t(
        'Halqani yopishga $meters metr qoldi.',
        '$meters meters to close the loop.',
        'До замыкания петли $meters метров.',
      );
  String sayFinish(double meters, double m2) => _t(
        'Yugurish tugadi. ${_spokenKm(meters)}. Yangi hudud: ${_spokenArea(m2)}.',
        'Run finished. ${_spokenKm(meters)}. New land: ${_spokenArea(m2)}.',
        'Пробежка завершена. ${_spokenKm(meters)}. Новая земля: ${_spokenArea(m2)}.',
      );

  String _spokenDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final parts = <String>[
      if (h > 0) _t('$h soat', '$h hours', '$h ч'),
      if (m > 0) _t('$m daqiqa', '$m minutes', '$m мин'),
      _t('$s soniya', '$s seconds', '$s сек'),
    ];
    return parts.join(' ');
  }

  String _spokenKm(double meters) => _t(
        '${_num(meters / 1000, 1)} kilometr',
        '${_num(meters / 1000, 1)} kilometers',
        '${_num(meters / 1000, 1)} км',
      );

  String _spokenArea(double m2) => m2 < 10000
      ? _t('${m2.round()} kvadrat metr', '${m2.round()} square meters', '${m2.round()} квадратных метров')
      : _t('${_num(m2 / 10000, 2)} gektar', '${_num(m2 / 10000, 2)} hectares', '${_num(m2 / 10000, 2)} гектара');

  String _ruPlural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }
}
