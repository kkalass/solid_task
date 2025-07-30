# SolidTask

A very simple cross-platform (flutter) Task-List app which can be connected to a SOLID Pod for cloud sync.

The goal is, to create a fully synced, offline first collaborative application. The usecase is a todo list, but the main point here is the technology. I view it as a collaborative activity since a user may use multiple devices with some of them possibly being offline - think of taking a short break, realizing that you did not track time yet and doing it on your mobile which happens to not have a network connection in your current location.

I want to explore the following in this project:

* how is it to code with heavy AI usage? (try out windsurf, cursor etc)
* Can AI also help with very non-standard architecture
* Dive deep into SOLID (Social Linked Data)
* Get a deeper understanding of CRDT

 So basically, I want to combine technologies that seem to be a really good match: Flutter for cross-platform, CRDT for distributed editing and conflict resolution, SOLID for cloud syncing where the users bring their storage service themselves, and AI assisted coding. All of this should be perfect for "hobby projects" where the developer is not interested in having direct access to the users data at all, has limited coding time and does not want to pay for some kind of servers.

## ⚠️ IMPORTANT REQUIREMENTS

**🚨 SOLID POD PROVIDER COMPATIBILITY**

This app uses **Solid-OIDC with Public Client Identifier Documents** for authentication. **NOT ALL SOLID POD PROVIDERS SUPPORT THIS FEATURE!**

### ✅ Compatible Providers (Tested)
- **Inrupt ESS** (Enterprise Solid Server) - `https://broker.pod.inrupt.com`
- **SolidCommunity.net** - `https://solidcommunity.net`
- **Community Solid Server** (self-hosted)

### ❌ Incompatible Providers (Known Issues)
- **iGrant.io** - `https://datapod.igrant.io` ❌ Does NOT support client identifier documents
- Any provider that only supports basic OIDC without Solid-OIDC extensions

### 📋 Requirements Checklist
Before using this app, make sure your Solid pod provider supports:
- ✅ **Solid-OIDC specification** (not just basic OIDC)
- ✅ **Client Identifier Documents** (WebID-based client identification)
- ✅ **Public clients** with `token_endpoint_auth_method: "none"`
- ✅ **WebID scope** in OIDC flows

### 🔍 How to Check Compatibility
1. Check if your provider's documentation mentions "Solid-OIDC" or "Client Identifier Documents"
2. Look for support of public clients (no client secret required)
3. Test authentication - if you get "Unauthorized" errors, the provider likely doesn't support this feature

### 🆘 If Your Provider Isn't Compatible
- Switch to a compatible provider (recommended: SolidCommunity.net for testing)
- Contact your provider to request Solid-OIDC support
- Consider self-hosting a Community Solid Server

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

## Building a solid flutter app from scratch

### Setup oidc

There are a few steps you have to perform in order to support 
oidc on the different platforms - you need to go through
https://bdaya-dev.github.io/oidc/oidc-getting-started/


### Deployment Requirements

#### Web Deployment

> **!!!** It is **very important** that the server has **HTTP Strict Forward Secrecy** enabled and sends the correct headers **!!!**

The headers should look like
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
```

#### Linux Deployment/Packaging

There are requirements for dependencies during packaging by flutter_secure_storage - e.g. check https://pub.dev/packages/flutter_secure_storage#configure-linux-version/ for details. 