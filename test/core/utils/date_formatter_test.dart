import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:solid_task/core/utils/date_formatter.dart';

void main() {
  // Setup to provide actual BuildContext with localizations
  setUp(() {
    initializeDateFormatting('de', null);
  });

  testWidgets(
    'DateFormatter.formatRelativeTime returns correct text for different time differences',
    (WidgetTester tester) async {
      // Create a fixed datetime for stable tests
      final now = DateTime(2025, 4, 10, 12, 0); // Today at noon

      // Create test cases with different time offsets
      final testCases = {
        'minutes': now.subtract(const Duration(minutes: 30)),
        'hours': now.subtract(const Duration(hours: 5)),
        'yesterday': now.subtract(const Duration(days: 1)),
        'days': now.subtract(const Duration(days: 3)),
        'old': now.subtract(const Duration(days: 10)),
      };

      // Render a widget with localizations
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Builder(
            builder: (BuildContext context) {
              // Test within the builder to get access to the BuildContext
              final l10n = AppLocalizations.of(context)!;

              // Test minutes case
              String result = DateFormatter.formatRelativeTime(
                testCases['minutes']!,
                context,
                currentTime: now,
              );
              expect(result, l10n.createdAgo(l10n.minutes(30)));

              // Test hours case
              result = DateFormatter.formatRelativeTime(
                testCases['hours']!,
                context,
                currentTime: now,
              );
              expect(result, l10n.createdAgo(l10n.hours(5)));

              // Test yesterday case
              result = DateFormatter.formatRelativeTime(
                testCases['yesterday']!,
                context,
                currentTime: now,
              );
              expect(result, l10n.yesterday);

              // Test days case
              result = DateFormatter.formatRelativeTime(
                testCases['days']!,
                context,
                currentTime: now,
              );
              expect(result, l10n.createdAgo(l10n.days(3)));

              // Test old date (more than a week)
              result = DateFormatter.formatRelativeTime(
                testCases['old']!,
                context,
                currentTime: now,
              );
              // For older dates, we can only verify it's not using one of the relative time formats
              expect(result, isNot(contains(l10n.days(10))));

              return const Placeholder();
            },
          ),
        ),
      );
    },
  );

  testWidgets('DateFormatter.formatShortDate returns date in proper format', (
    WidgetTester tester,
  ) async {
    final date = DateTime(2025, 3, 15);

    // Render a widget with localizations
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Builder(
          builder: (BuildContext context) {
            final result = DateFormatter.formatShortDate(date, context);
            // Expect German format DD.M.YYYY (without leading zero for single-digit months)
            expect(result, '15.3.2025');
            return const Placeholder();
          },
        ),
      ),
    );
  });

  testWidgets(
    'DateFormatter.formatDateTime returns date and time in proper format',
    (WidgetTester tester) async {
      final date = DateTime(2025, 3, 15, 14, 30);

      // Render a widget with localizations
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Builder(
            builder: (BuildContext context) {
              final result = DateFormatter.formatDateTime(date, context);
              // Expect German format with month name
              expect(result, contains('15.'));
              expect(result, contains('März'));
              expect(result, contains('2025'));
              expect(result, contains('14:30'));
              return const Placeholder();
            },
          ),
        ),
      );
    },
  );
}
