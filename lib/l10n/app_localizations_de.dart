// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Meine Aufgaben';

  @override
  String get addTaskHint => 'Neue Aufgabe hinzufügen...';

  @override
  String get noTasks => 'Noch keine Aufgaben';

  @override
  String createdAgo(String time) {
    return 'vor $time';
  }

  @override
  String get yesterday => 'Gestern';

  @override
  String minutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Minuten',
      one: 'Minute',
    );
    return '$_temp0';
  }

  @override
  String hours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stunden',
      one: 'Stunde',
    );
    return '$_temp0';
  }

  @override
  String days(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String get connectToSolid => 'Mit Solid Pod verbinden';

  @override
  String get syncAcrossDevices =>
      'Synchronisiere deine Aufgaben über alle Geräte';

  @override
  String get enterWebId =>
      'Gib deine Solid WebID oder Issuer-URL ein, um die Cloud-Synchronisierung zu aktivieren';

  @override
  String get webIdHint => 'Deine WebID oder Issuer-URL eingeben';

  @override
  String get webIdExample =>
      'z.B. https://dein-pod-anbieter.de/profile/card#me';

  @override
  String get connect => 'Verbinden';

  @override
  String errorConnectingSolid(String error) {
    return 'Fehler bei der Verbindung mit Solid: $error';
  }

  @override
  String get noPod => 'Noch keinen Solid Pod?';

  @override
  String get getPod => 'Hier einen erstellen';

  @override
  String get syncedWithPod => 'Mit Solid Pod synchronisiert';

  @override
  String get connectToPod => 'Mit Solid Pod verbinden';

  @override
  String get chooseProvider => 'Wähle deinen Solid Pod-Anbieter';

  @override
  String get orEnterManually => 'Oder gib deine WebID manuell ein';

  @override
  String get disconnectFromPod => 'Solid Pod trennen';

  @override
  String get errorDisconnecting => 'Fehler beim Trennen vom Solid Pod';

  @override
  String get syncError => 'Synchronisationsfehler, zum Wiederholen tippen';
}
