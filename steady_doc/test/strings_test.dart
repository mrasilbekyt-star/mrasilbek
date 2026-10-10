import 'package:flutter_test/flutter_test.dart';
import 'package:steady_doc/game/levels.dart';
import 'package:steady_doc/l10n/strings.dart';

void main() {
  test('patients are described in each language', () {
    expect(const Strings('uz').patient(Sex.male, 24), 'Erkak, 24 yosh');
    expect(const Strings('en').patient(Sex.female, 31), 'Female, 31');
    expect(const Strings('ru').patient(Sex.male, 21), 'Мужчина, 21 год');
    expect(const Strings('ru').patient(Sex.female, 52), 'Женщина, 52 года');
    expect(const Strings('ru').patient(Sex.male, 45), 'Мужчина, 45 лет');
    expect(const Strings('ru').patient(Sex.male, 12), 'Мужчина, 12 лет');
  });

  test('repeated findings are counted', () {
    expect(const Strings('en').findings(['magnet', 'magnet', 'battery']), 'magnet ×2, battery');
    expect(const Strings('uz').findings(['gallstone', 'gallstone']), "o't toshi ×2");
  });

  test('every finding has a name', () {
    for (final id in findingEmoji.keys) {
      // Unknown ids fall back to the id itself; Russian names never match it.
      expect(const Strings('ru').finding(id), isNot(id), reason: id);
      for (final lang in Strings.supported) {
        expect(Strings(lang).finding(id), isNotEmpty);
      }
    }
  });
}
