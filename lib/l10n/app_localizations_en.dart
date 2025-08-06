// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'My Tasks';

  @override
  String get addTaskHint => 'Add a new task...';

  @override
  String get noTasks => 'No tasks yet';

  @override
  String createdAgo(String time) {
    return '$time ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String minutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'minutes',
      one: 'minute',
    );
    return '$_temp0';
  }

  @override
  String hours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return '$_temp0';
  }

  @override
  String days(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get connectToSolid => 'Connect to Solid Pod';

  @override
  String get syncAcrossDevices => 'Sync your tasks across devices';

  @override
  String get enterWebId =>
      'Enter your Solid WebID or Issuer URL to enable cloud synchronization';

  @override
  String get webIdHint => 'Enter your WebID or Issuer URL';

  @override
  String get webIdExample =>
      'e.g., https://your-pod-provider.com/profile/card#me';

  @override
  String get connect => 'Connect';

  @override
  String errorConnectingSolid(String error) {
    return 'Error connecting to Solid: $error';
  }

  @override
  String get noPod => 'Don\'t have a Solid Pod yet?';

  @override
  String get getPod => 'Get one here';

  @override
  String get syncedWithPod => 'Synced with Solid Pod';

  @override
  String get connectToPod => 'Connect to Solid Pod';

  @override
  String get chooseProvider => 'Choose your Solid Pod provider';

  @override
  String get orEnterManually => 'Or enter your WebID manually';

  @override
  String get disconnectFromPod => 'Disconnect from Solid Pod';

  @override
  String get errorDisconnecting => 'Error disconnecting from Solid Pod';

  @override
  String get syncError => 'Sync error, tap to retry';
}
