// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'S.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get settings => 'Paramètres';

  @override
  String get generalSettings => 'Paramètres généraux';

  @override
  String get accessibilitySettings => 'Paramètres d\'accessibilité';

  @override
  String get languageSettings => 'Paramètres linguistiques';

  @override
  String get selectLanguage => 'Choisir la langue';
}
