<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->
**English** | [Русский](README.ru.md)

Unified base Firebase integration for Flutter applications based on 
[application_base package](https://github.com/AlexSeednov/application_base)
with 
[special architecture](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014)

## Features

For now includes:
* [Firebase Core](#firebase-core)
* [Firebase Crashlytics](#firebase-crashlytics)
* [Firebase Cloud Messaging](#firebase-cloud-messaging)
* [Local notifications](#local-notifications)

## Supported platforms

* Android
* iOS
* Web — compiles and launches, but with limitations, see 
  [Web support](#web-support)

All other not supported because of 
[awesome_notifications](https://pub.dev/packages/awesome_notifications)

## Web support

The package compiles and runs on web, degrading to the necessary minimum:

* **Firebase Core** — initializes only when explicit `FirebaseOptions` are 
  passed to `FirebaseBase.prepare`: on web there is no native config file to 
  read them from. Without them the whole Firebase stack is skipped cleanly 
  (with an info log).
* **Crashlytics** — not supported by FlutterFire on web at all (the plugin 
  does not even compile there). Inside the package the SDK is isolated behind 
  a conditional import (`CrashlyticsReporter`) and replaced with a silent 
  no-op on web; the global error handlers and the remote logger are left 
  untouched.
* **Cloud Messaging** — technically possible on web (FCM Web Push), but not 
  implemented yet: it requires a `firebase-messaging-sw.js` service worker in 
  the consuming application and a VAPID key for `getToken`. For now `prepare` 
  skips messaging on web with an info log. Browser-side limitations to keep 
  in mind: pushes are displayed by the browser itself, and Safari on iOS 
  delivers them only to a PWA installed on the home screen.
* **Local notifications** — `awesome_notifications` is used only on the 
  Android foreground path and is never touched on web.

## Requirements 

Based on minimum requirements from 
[application_base package](https://github.com/AlexSeednov/application_base)

## Changelog

Refer to the 
[Changelog](https://github.com/AlexSeednov/firebase_base/blob/main/CHANGELOG.md) 
to get all release notes

## Usage

Add a line like this to your package's pubspec.yaml (and run an implicit 
flutter pub get):

```yaml
  # Not supported: Linux | macOS | Windows
  firebase_base:
    git:
      url: https://github.com/AlexSeednov/firebase_base
      tag_pattern: v{{version}}
    version: 0.2.8
```

Now just call `FirebaseBase -> prepare` on application launching to initialize 
all necessary data.

```dart
// Wire the package's injectable module into your service locator:
import 'package:firebase_base/core/service/service_locator_firebase.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(FirebaseBasePackageModule)],
)
Future<void> configureDependencies() => getIt.init();

// On launch — await DI init, then initialize Firebase:
await configureDependencies();
await FirebaseBase.prepare(name: applicationName);
```
where `applicationName` is Android application name for system notification setting.

`getIt.init()` is asynchronous when external package modules are wired, so
**await** it. `FirebaseBase.prepare` resolves the registered services, so it
must run **after** `getIt.init()` has completed.

On **Android** you can also pass two optional parameters that configure the
notification channel and the status bar icon (see 
[Local notifications](#local-notifications)):

```dart
await FirebaseBase.prepare(
  name: applicationName,
  channelKey: 'app-notifications',                  // must match the manifest
  icon: 'resource://drawable/ic_stat_notification', // monochrome small icon
);
```

All four services are getIt-owned singletons, registered by the package's
injectable module (`@lazySingleton`); resolve them via `getIt<T>()` or inject
them through a constructor.

## Firebase Core

Based on [firebase_core](https://pub.dev/packages/firebase_core).

All necessary data will be initiated by using `FirebaseBase -> prepare`. 
But if you want to set custom Firebase project options, you can pass 
`FirebaseOptions` to the `prepare` function. Do not forget to add 
`firebase_core` package in `pubspec.yaml`

```yaml
  # https://pub.dev/packages/firebase_core
  firebase_core: ^4.11.0
```

## Firebase Crashlytics

Based on [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics).

All necessary data will be initiated by using `FirebaseBase -> prepare`. 

If the application reports crashes through another tool, turn Crashlytics off
and keep the rest of Firebase:

```dart
await FirebaseBase.prepare(
  name: applicationName,
  isCrashlyticsEnabled: false,
);
```

The flag does more than skip the Dart handlers: the native SDK starts
collecting together with `Firebase.initializeApp`, so the package also calls
`setCrashlyticsCollectionEnabled(false)` — otherwise native crashes would keep
reaching Firebase after the app moved on. The setting persists across launches,
so an app that switches back gets its reporting restored by the `true` branch.
Remove the *Crashlytics Upload Symbols* build phase from the iOS project as
well, or the build keeps uploading dSYM files to a project nobody reads.

## Firebase Cloud Messaging

Based on [firebase_messaging](https://pub.dev/packages/firebase_messaging).

Setup Firebase instruction [here](https://firebase.google.com/docs/cloud-messaging/flutter/client)

How a message is shown depends on the application state and the OS.
Application state can be:

* **Foreground** - When the application is open, in view and in use

* **Background** - When the application is open, but in the background 
(minimized). This typically occurs when the user has pressed the "home" 
button on the device, has switched to another app using the app switcher, 
or has the application open in a different tab (web)

* **Terminated** - When the device is locked or the application is not running

In **Foreground** pushes will be shown after some preparations:

* On **Android** FCM does not show a notification that arrives while the
application is in the foreground. The package shows it itself, as a local
notification on a high importance channel — see
[Local notifications](#local-notifications)

* On **iOS**, you can update the presentation options for the application via 
`FirebaseMessaging -> setForegroundNotificationPresentationOptions`

Details in [Firebase docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive)

A diagram with the overall picture [here](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png)

FCM Device token available via **FirebaseMessagingService->token**.

Example:

```dart
getIt<FirebaseMessagingService>().token;
```

To get data from Push's payload you need to listen `pushSubject` stream. 
On listening this stream will return previous payload if it was.
Payload - `Map<String, dynamic>`

Example:

```dart
///
StreamSubscription<Map<String, dynamic>>? _subscription;

///
void prepare() {
    _subscription =
        getIt<FirebaseMessagingService>().pushSubject.listen(_onData);
}

///
void dispose() {
    _subscription?.cancel();
}

///
void _onData(Map<String, dynamic> payload) {
    /// Do some stuff here
}
```

**Important** do not forget to ask user notifications permission via
`FirebaseMessagingService->requestPermission`.

Example

```dart
final status = await getIt<FirebaseMessagingService>().requestPermission();
```

It's better for UX to call it once, on user Authorization / Registration only.


## Local notifications

Based on [awesome_notifications](https://pub.dev/packages/awesome_notifications)

Used only on **Android** to show push notifications, got in **Foreground** 
application state.

Supports title, body and image.

### Notification channel (`channelKey`)

On Android a push is shown by two different mechanisms depending on the
application state:

* **Foreground** - by this package via `awesome_notifications`, on the channel
created here;
* **Background / Terminated** - by FCM itself, on the channel declared in the
app manifest as `com.google.firebase.messaging.default_notification_channel_id`.

For both to use the same **high importance** channel (and therefore show a
heads-up banner), the `channelKey` passed to `prepare` MUST exactly match the
manifest value. If they differ, FCM falls back to a default-importance channel
and pushes arrive without a banner. Keep the key flavor-independent — channels
are per-app, so different flavors (with different `applicationId`) do not clash.

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="app-notifications" />
```

When `channelKey` is omitted it falls back to the legacy `'<name>-notifications'`
key for backward compatibility.

### Small icon (`icon`)

Android renders the status bar / notification small icon using only its alpha
channel as a white (then tinted) silhouette. Provide a dedicated **monochrome**
(transparent + white) drawable, otherwise the launcher icon is used and shows as
a white blob (or nothing on some OEMs, e.g. Xiaomi/MIUI).

Pass it as `icon: 'resource://drawable/ic_stat_notification'` for the foreground
path, and declare the same drawable for the FCM background path in the manifest:

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_icon"
  android:resource="@drawable/ic_stat_notification" />
```

When `icon` is omitted the application launcher icon is used.

