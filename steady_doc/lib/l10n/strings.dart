import '../game/levels.dart';
import '../game/stages.dart';

/// All player-facing text, in Uzbek, English and Russian.
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

  String get appTitle => 'Steady Doc';
  String get tagline => _t(
        'Haqiqiy jarrohlik simulyatori.\nS Pen uchun yaratilgan.',
        'A realistic surgery simulator.\nMade for the S Pen.',
        'Реалистичный симулятор хирурга.\nСоздан для S Pen.',
      );

  String get play => _t("O'ynash", 'Play', 'Играть');
  String get settings => _t('Sozlamalar', 'Settings', 'Настройки');
  String get language => _t('Til', 'Language', 'Язык');
  String get sound => _t('Ovoz', 'Sound', 'Звук');
  String get vibration => _t('Vibratsiya', 'Vibration', 'Вибрация');
  String get resetProgress =>
      _t('Natijalarni tozalash', 'Reset progress', 'Сбросить прогресс');
  String get resetConfirm => _t(
        "Barcha yulduzlar o'chiriladi. Ishonchingiz komilmi?",
        'All stars will be erased. Are you sure?',
        'Все звёзды будут удалены. Вы уверены?',
      );
  String get cancel => _t('Bekor qilish', 'Cancel', 'Отмена');
  String get yes => _t('Ha', 'Yes', 'Да');
  String get patients => _t('Bemorlar', 'Patients', 'Пациенты');
  String patientNumber(int n) =>
      _t('$n-bemor', 'Patient $n', 'Пациент $n');
  String get toRemove =>
      _t('Olib tashlash kerak:', 'To remove:', 'Удалить:');

  String get diagnosisLabel => _t('Tashxis:', 'Diagnosis:', 'Диагноз:');

  String diagnosis(Diagnosis d) => switch (d) {
        Diagnosis.foreignBody => _t('Yutib yuborilgan yot jism',
            'Swallowed foreign body', 'Проглоченное инородное тело'),
        Diagnosis.fishhook => _t('Kaftga kirgan qarmoq', 'Fish hook in the palm',
            'Рыболовный крючок в ладони'),
        Diagnosis.appendicitis =>
          _t("O'tkir appenditsit", 'Acute appendicitis', 'Острый аппендицит'),
        Diagnosis.glass => _t('Qorin devoridagi shisha parchalari',
            'Glass shards in the abdominal wall', 'Осколки стекла в брюшной стенке'),
        Diagnosis.gallstones =>
          _t("O't tosh kasalligi", 'Gallstones', 'Желчнокаменная болезнь'),
        Diagnosis.looseBodies => _t('Tizzadagi suyak parchalari',
            'Loose bone fragments in the knee', 'Костные фрагменты в колене'),
        Diagnosis.kidneyStones =>
          _t('Buyrak tosh kasalligi', 'Kidney stones', 'Мочекаменная болезнь'),
        Diagnosis.metal => _t('Yelkadagi metall parchalari',
            'Metal fragments in the shoulder', 'Металлические осколки в плече'),
      };

  String patient(Sex sex, int age) => switch (lang) {
        'uz' => '${sex == Sex.male ? 'Erkak' : 'Ayol'}, $age yosh',
        'ru' => '${sex == Sex.male ? 'Мужчина' : 'Женщина'}, $age ${_years(age)}',
        _ => '${sex == Sex.male ? 'Male' : 'Female'}, $age',
      };

  static String _years(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'год';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) return 'года';
    return 'лет';
  }

  String finding(String id) => switch (id) {
        'coin' => _t('tanga', 'coin', 'монета'),
        'ring' => _t('uzuk', 'ring', 'кольцо'),
        'key' => _t('kalit', 'key', 'ключ'),
        'denture' => _t('tish protezi', 'denture', 'зубной протез'),
        'battery' => _t('batareya', 'battery', 'батарейка'),
        'magnet' => _t('magnit', 'magnet', 'магнит'),
        'gallstone' => _t("o't toshi", 'gallstone', 'желчный камень'),
        'bolt' => _t('bolt', 'bolt', 'болт'),
        'pin' => _t("to'g'nag'ich", 'safety pin', 'булавка'),
        'dice' => _t("o'yin soqqasi", 'die', 'игральная кость'),
        'pawn' => _t('shaxmat donasi', 'chess pawn', 'шахматная пешка'),
        'spoon' => _t('qoshiq', 'spoon', 'ложка'),
        'toothbrush' => _t("tish cho'tkasi", 'toothbrush', 'зубная щётка'),
        'kidneystone' => _t('buyrak toshi', 'kidney stone', 'почечный камень'),
        'fishhook' => _t('qarmoq', 'fish hook', 'рыболовный крючок'),
        'appendix' => _t("yallig'langan appendiks", 'inflamed appendix', 'воспалённый аппендикс'),
        'glass' => _t('shisha parchasi', 'glass shard', 'осколок стекла'),
        'bone' => _t('suyak parchasi', 'bone fragment', 'костный фрагмент'),
        'metal' => _t('metall parcha', 'metal fragment', 'металлический осколок'),
        _ => id,
      };

  /// "magnet ×2, battery".
  String findings(List<String> ids) {
    final counts = <String, int>{};
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries) e.value > 1 ? '${finding(e.key)} ×${e.value}' : finding(e.key),
    ].join(', ');
  }

  String get alarm => _t('XAVF', 'ALARM', 'ТРЕВОГА');
  String get version => _t('Versiya', 'Version', 'Версия');

  String stageName(StageKind kind) => switch (kind) {
        StageKind.inject => _t('Ukol', 'Anesthesia', 'Наркоз'),
        StageKind.xray => _t('Rentgen', 'X-ray', 'Рентген'),
        StageKind.cut => _t('Kesish', 'Incision', 'Разрез'),
        StageKind.extract => _t('Chiqarish', 'Extraction', 'Извлечение'),
        StageKind.stitch => _t('Tikish', 'Stitches', 'Швы'),
      };

  String instruction(StageKind kind) => switch (kind) {
        StageKind.inject => _t(
            "Porshenni SEKIN pastga torting. Shoshilsangiz og'riydi!",
            'Drag the plunger down SLOWLY. Rushing hurts!',
            'МЕДЛЕННО тяните поршень вниз. Спешка — это больно!',
          ),
        StageKind.xray => _t(
            "S Pen'ni tanaga tegizmasdan ustida yurgizing (yoki barmoq bilan suring). Har bir narsa ustida biroz to'xtang.",
            'Hover the S Pen over the body (or drag a finger). Pause over each object.',
            'Водите S Pen над телом (или пальцем). Задержитесь над каждым предметом.',
          ),
        StageKind.cut => _t(
            "Yashil nuqtadan boshlab nuqtali chiziq bo'ylab kesing. Ruchkani qattiq bosmang!",
            "Cut along the dotted line from the green dot. Don't press too hard!",
            'Режьте по пунктиру от зелёной точки. Не давите слишком сильно!',
          ),
        StageKind.extract => _t(
            'Har bir narsani pinset bilan ushlab, devorlarga tegizmasdan teshikka olib chiqing.',
            'Grab each object and pull it to the hole without touching the walls.',
            'Хватайте каждый предмет и тащите к отверстию, не касаясь стенок.',
          ),
        StageKind.stitch => _t(
            'Yarani tiking: nuqtalarni ketma-ket, chiziqdan chiqmasdan ulang.',
            'Stitch the wound: connect the dots in order without straying.',
            'Зашейте рану: соединяйте точки по порядку, не отклоняясь.',
          ),
      };

  String mistake(MistakeKind kind) => switch (kind) {
        MistakeKind.offLine =>
          _t('Chiziqdan chiqdi!', 'Off the line!', 'Мимо линии!'),
        MistakeKind.tooDeep =>
          _t('Juda chuqur!', 'Too deep!', 'Слишком глубоко!'),
        MistakeKind.tooFast => _t('Juda tez!', 'Too fast!', 'Слишком быстро!'),
        MistakeKind.wall =>
          _t('Bzzz! Devorga tegdi!', 'Bzzz! Hit the wall!', 'Бззз! Стенка!'),
        MistakeKind.tooHard =>
          _t('Juda qattiq!', 'Too hard!', 'Слишком сильно!'),
      };

  String get great =>
      _t('Bosqich yakunlandi', 'Stage complete', 'Этап завершён');
  String get won => _t(
        'Operatsiya muvaffaqiyatli!',
        'Operation successful!',
        'Операция прошла успешно!',
      );
  String get failed => _t(
        'Bemor hushidan ketdi!',
        'The patient fainted!',
        'Пациент потерял сознание!',
      );
  String get failHint => _t(
        "Yurak urishi juda tezlashib ketdi. Sekinroq va ehtiyotkorroq bo'ling.",
        'The heart rate got too high. Go slower and steadier.',
        'Пульс слишком высокий. Действуйте медленнее и аккуратнее.',
      );
  String get mistakes => _t('Xatolar', 'Mistakes', 'Ошибки');
  String get time => _t('Vaqt', 'Time', 'Время');
  String get next => _t('Keyingi bemor', 'Next patient', 'Следующий пациент');
  String get retry => _t('Qayta urinish', 'Try again', 'Ещё раз');
  String get menu => _t('Menyu', 'Menu', 'Меню');
  String get resume => _t('Davom etish', 'Resume', 'Продолжить');
  String get paused => _t('Pauza', 'Paused', 'Пауза');
  String get penDetected => _t(
        'S Pen aniqlandi: bosim kuchi va hover yoqildi',
        'S Pen detected: pressure and hover are on',
        'S Pen обнаружен: нажим и наведение включены',
      );
  String get allCured => _t(
        "Barcha bemorlar davolandi. Tez orada yangi holatlar qo'shiladi.",
        'Every patient is treated. New cases are coming soon.',
        'Все пациенты вылечены. Скоро появятся новые случаи.',
      );
}
