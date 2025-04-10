import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Utility class for formatting dates in a human-readable way.
///
/// This class provides functionality similar to moment.js for relative time formatting,
/// tailored for the application's needs. It supports localization and various
/// time formats.
class DateFormatter {
  /// Formats a date relative to the current time (e.g., "5 minutes ago")
  ///
  /// Uses the app's localization for proper translations.
  ///
  /// @param date The date to format
  /// @param context BuildContext used to access localization resources
  /// @param currentTime Optional parameter to specify the reference time for testing
  /// @return A localized string representing the relative time
  static String formatRelativeTime(
    DateTime date,
    BuildContext context, {
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final difference = now.difference(date);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        final minutes = difference.inMinutes;
        return l10n.createdAgo(l10n.minutes(minutes));
      }
      final hours = difference.inHours;
      return l10n.createdAgo(l10n.hours(hours));
    } else if (difference.inDays == 1) {
      return l10n.yesterday;
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return l10n.createdAgo(l10n.days(days));
    } else {
      return DateFormat.yMd(
        Localizations.localeOf(context).languageCode,
      ).format(date);
    }
  }

  /// Formats a date into a standard short date format based on locale
  ///
  /// @param date The date to format
  /// @param context BuildContext used to access locale information
  /// @return A localized date string in short format
  static String formatShortDate(DateTime date, BuildContext context) {
    return DateFormat.yMd(
      Localizations.localeOf(context).languageCode,
    ).format(date);
  }

  /// Formats a date into a medium date format with time
  ///
  /// @param date The date to format
  /// @param context BuildContext used to access locale information
  /// @return A localized date and time string
  static String formatDateTime(DateTime date, BuildContext context) {
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).add_Hm().format(date);
  }
}
