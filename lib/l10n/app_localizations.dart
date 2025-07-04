import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get appTitle;

  /// Hint text for the task input field
  ///
  /// In en, this message translates to:
  /// **'Add a new task...'**
  String get addTaskHint;

  /// Text shown when there are no tasks
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasks;

  /// Text showing how long ago a task was created
  ///
  /// In en, this message translates to:
  /// **'{time} ago'**
  String createdAgo(String time);

  /// Text for tasks created yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Plural form for minutes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{minute} other{minutes}}'**
  String minutes(num count);

  /// Plural form for hours
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{hour} other{hours}}'**
  String hours(num count);

  /// Plural form for days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String days(num count);

  /// Title for the Solid connection screen
  ///
  /// In en, this message translates to:
  /// **'Connect to Solid Pod'**
  String get connectToSolid;

  /// Description for Solid connection
  ///
  /// In en, this message translates to:
  /// **'Sync your tasks across devices'**
  String get syncAcrossDevices;

  /// Instructions for entering WebID
  ///
  /// In en, this message translates to:
  /// **'Enter your WebID or Solid Pod issuer URL to enable cloud synchronization'**
  String get enterWebId;

  /// Hint text for WebID input
  ///
  /// In en, this message translates to:
  /// **'Enter your WebID or Pod URL'**
  String get webIdHint;

  /// Example WebID URL
  ///
  /// In en, this message translates to:
  /// **'e.g., https://your-pod-provider.com/profile/card#me'**
  String get webIdExample;

  /// Text for connect button
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Error message when connecting to Solid fails
  ///
  /// In en, this message translates to:
  /// **'Error connecting to Solid: {error}'**
  String errorConnectingSolid(String error);

  /// Text for users without a Solid Pod
  ///
  /// In en, this message translates to:
  /// **'Don\'t have a Solid Pod yet?'**
  String get noPod;

  /// Text for getting a new Pod
  ///
  /// In en, this message translates to:
  /// **'Get one here'**
  String get getPod;

  /// Tooltip for sync status when connected
  ///
  /// In en, this message translates to:
  /// **'Synced with Solid Pod'**
  String get syncedWithPod;

  /// Tooltip for sync status when not connected
  ///
  /// In en, this message translates to:
  /// **'Connect to Solid Pod'**
  String get connectToPod;

  /// Header text for the provider selection section
  ///
  /// In en, this message translates to:
  /// **'Choose your Solid Pod provider'**
  String get chooseProvider;

  /// Text shown above the manual WebID input field
  ///
  /// In en, this message translates to:
  /// **'Or enter your WebID manually'**
  String get orEnterManually;

  /// Tooltip for disconnect button
  ///
  /// In en, this message translates to:
  /// **'Disconnect from Solid Pod'**
  String get disconnectFromPod;

  /// Error message shown when disconnecting fails
  ///
  /// In en, this message translates to:
  /// **'Error disconnecting from Solid Pod'**
  String get errorDisconnecting;

  /// Error message shown when synchronization fails
  ///
  /// In en, this message translates to:
  /// **'Sync error, tap to retry'**
  String get syncError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
