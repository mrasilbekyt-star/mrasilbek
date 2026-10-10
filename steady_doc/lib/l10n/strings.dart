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
        "Qo'li titramaydigan jarroh o'yini.\nS Pen bilan yanada zo'r ✍️",
        'A steady-hand surgery game.\nEven better with an S Pen ✍️',
        'Игра для хирурга с твёрдой рукой.\nЕщё лучше с S Pen ✍️',
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
  String get swallowed =>
      _t('Yutib yuborgan:', 'Swallowed:', 'Проглотил(а):');
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

  String get great => _t('Ajoyib!', 'Great!', 'Отлично!');
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
        'S Pen aniqlandi ✍️ Bosim kuchi va hover yoqildi',
        'S Pen detected ✍️ Pressure and hover are on',
        'S Pen обнаружен ✍️ Нажим и наведение включены',
      );
  String get allCured => _t(
        'Hammani davoladingiz! Tez orada yangi bemorlar keladi.',
        'You cured everyone! More patients coming soon.',
        'Вы вылечили всех! Скоро придут новые пациенты.',
      );
}
