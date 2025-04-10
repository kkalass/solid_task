# SolidTask

A very simple cross-platform (flutter) Task-List app which can be connected to a SOLID Pod for cloud sync.

The goal is, to create a fully synced, offline first collaborative application. The usecase is a todo list, but the main point here is the technology. I view it as a collaborative activity since a user may use multiple devices with some of them possibly being offline - think of taking a short break, realizing that you did not track time yet and doing it on your mobile which happens to not have a network connection in your current location.

I want to explore the following in this project:

* how is it to code with heavy AI usage? (try out windsurf, cursor etc)
* Can AI also help with very non-standard architecture
* Dive deep into SOLID (Social Linked Data)
* Get a deeper understanding of CRDT

 So basically, I want to combine technologies that seem to be a really good match: Flutter for cross-platform, CRDT for distributed editing and conflict resolution, SOLID for cloud syncing where the users bring their storage service themselves, and AI assisted coding. All of this should be perfect for "hobby projects" where the developer is not interested in having direct access to the users data at all, has limited coding time and does not want to pay for some kind of servers.

## Status

**THIS IS WORK IN PROGRESS!!!**

This is not even really a 0.0.1 release, it is a complete work in progress

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

* [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
* [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Building

```sh
flutter gen-l10n # only needed when i18n was changed
flutter run -d macos
```

## Required Rights

### NSAllowsArbitraryLoads

This is necessary because:

* Users can enter any Solid Pod provider URL
* The app needs to fetch favicons from these URLs
* The app needs to communicate with the Pod for authentication and data synchronization
