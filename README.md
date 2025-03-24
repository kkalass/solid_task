# my_cross_platform_app

A new Flutter project, which is implemented fully with the help of AI. I will try to keep track
of the prompts to the coding AI in the commit messages, and record additional AI input in the 
`chats` directory.

The goal is, to create a fully synced, offline first collaborative application. The usecase is a time tracking app, but the main point here is the technology. Even though time is typically tracked by a single person, I view it as a collaborative activity since a user may use multiple devices with some of them possibly being offline - think of taking a short break, realizing that you did not track time yet and doing it on your mobile which happens to not have a network connection in your current location.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Building

```
flutter gen-l10n # only needed when i18n was changed
flutter run -d macos
```

## Required Rights

### NSAllowsArbitraryLoads
This is necessary because:
* Users can enter any Solid Pod provider URL
* The app needs to fetch favicons from these URLs
* The app needs to communicate with the Pod for authentication and data synchronization
