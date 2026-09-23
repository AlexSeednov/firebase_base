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

Unified base Firebase integration for Flutter applications based on the
[application_base package](https://github.com/AlexSeednov/application_base)
with a
[special architecture](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014).

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

All other platforms are not supported because of
[awesome_notifications](https://pub.dev/packages/awesome_notifications).

## Web support

The package compiles and runs on the web, but does less there:

* **Firebase Core** initializes only when explicit `FirebaseOptions` are
  passed to `FirebaseBase.prepare`: on the web there is no native config file
  to read them from. Without them the whole Firebase stack is skipped, with an
  info line in the log.
* **Crashlytics** is not supported by FlutterFire on the web at all, the plugin
  does not even compile there. Inside the package the SDK sits behind a
  conditional import (`CrashlyticsReporter`) and is replaced with an empty stub
  on the web. The global error handlers and the remote logger work as usual.
* **Cloud Messaging** is technically possible on the web (FCM Web Push), but
  not implemented yet. It needs a `firebase-messaging-sw.js` service worker in
  the application and a VAPID key for `getToken`. For now `prepare` skips
  messaging on the web with an info line in the log. Keep the browser's own
  limits in mind too: pushes are displayed by the browser itself, and Safari on
  iOS delivers them only to a PWA installed on the home screen.
* **Local notifications** are needed only on the Android foreground path, on
  the web `awesome_notifications` is never touched.

## Requirements

Based on the minimum requirements of the
[application_base package](https://github.com/AlexSeednov/application_base).

## Changelog

Refer to the
[Changelog](https://github.com/AlexSeednov/firebase_base/blob/main/CHANGELOG.md)
for all release notes.

## Usage

1. Add an entry like this to the application's `pubspec.yaml` (and run
   `flutter pub get`):

```yaml
  # Not supported: Linux | macOS | Windows
  firebase_base:
    git:
      url: https://github.com/AlexSeednov/firebase_base
      tag_pattern: v{{version}}
    version: 0.2.8
```

2. Wire the package's injectable module into your service locator:

```dart
import 'package:firebase_base/core/service/service_locator_firebase.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(FirebaseBasePackageModule)],
)
Future<void> configureDependencies() => getIt.init();
```

3. On launch await the DI init, then call `FirebaseBase.prepare`:

```dart
await configureDependencies();
await FirebaseBase.prepare(name: applicationName);
```

`applicationName` is the name under which the application's notifications
appear in the Android system settings.

The order matters. `getIt.init()` is asynchronous when external package
modules are wired, so **await** it. `FirebaseBase.prepare` takes the services
from getIt, so it must run **after** `getIt.init()` has completed.

`prepare` returns a `bool`: whether every part started. It never throws: a
broken Firebase setup degrades the application instead of blocking its launch,
and what to do without Firebase is the caller's decision. Without Firebase
Core, messaging does not start.

On **Android** two more optional parameters can be passed: the notification
channel and the status bar icon (see
[Local notifications](#local-notifications)):

```dart
await FirebaseBase.prepare(
  name: applicationName,
  channelKey: 'app-notifications',                  // must match the manifest
  icon: 'resource://drawable/ic_stat_notification', // monochrome small icon
);
```

The package has four services: `FirebaseService`, `CrashlyticsService`,
`FirebaseMessagingService` and `LocalNotificationsService`. All of them are
singletons owned by getIt, registered by the package's injectable module
(`@lazySingleton`). Take them via `getIt<T>()` or through a constructor.

## Firebase Core

Based on [firebase_core](https://pub.dev/packages/firebase_core).

Everything needed is initialized by `FirebaseBase.prepare`. For custom
Firebase project options pass `FirebaseOptions` to it. The `firebase_core`
package has to be in the application's `pubspec.yaml` as well:

```yaml
  # https://pub.dev/packages/firebase_core
  firebase_core: ^4.11.0
```

## Firebase Crashlytics

Based on [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics).

Everything needed is initialized by `FirebaseBase.prepare`.

If the application reports crashes through another tool, turn Crashlytics off
and keep the rest of Firebase:

```dart
await FirebaseBase.prepare(
  name: applicationName,
  isCrashlyticsEnabled: false,
);
```

What happens then:

* The flag does more than skip the Dart handlers. The native SDK starts
  collecting together with `Firebase.initializeApp`, so the package also calls
  `setCrashlyticsCollectionEnabled(false)`. Otherwise native crashes would
  keep reaching Firebase after the application moved on.
* The setting persists across launches. An application that comes back to
  Crashlytics just passes `true` again: that branch switches collection back
  on.
* Remove the *Crashlytics Upload Symbols* build phase from the iOS project as
  well, or the build keeps uploading dSYM files to a project nobody reads.

## Firebase Cloud Messaging

Based on [firebase_messaging](https://pub.dev/packages/firebase_messaging).

Firebase setup instructions:
[here](https://firebase.google.com/docs/cloud-messaging/flutter/client).

How a message is shown depends on the application state and the OS. The
application states:

* **Foreground** — the application is open, in view and in use.
* **Background** — the application is open, but in the background
  (minimized). This typically happens when the user has pressed the "home"
  button, switched to another app through the app switcher, or has the
  application open in a different tab (web).
* **Terminated** — the device is locked or the application is not running.

For a push to show in **Foreground** some preparation is needed:

* On **Android** FCM does not show a notification that arrives while the
  application is in the foreground. The package shows it itself, as a local
  notification on a high-importance channel, see
  [Local notifications](#local-notifications).
* On **iOS** the presentation options are set through
  `FirebaseMessaging.setForegroundNotificationPresentationOptions`.

Details in the
[Firebase docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive),
a diagram with the overall picture
[here](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png).

### Token and payload

The FCM device token comes from `FirebaseMessagingService.token`, with
`apnsToken` next to it on iOS:

```dart
getIt<FirebaseMessagingService>().token;
```

The data of a push payload arrives in the `pushSubject` stream. A payload is a
`Map<String, dynamic>`. A new listener gets the previous payload at once, if
there was one:

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

### Notification permission

`FirebaseMessagingService.requestPermission` asks the user for the permission:

```dart
final status = await getIt<FirebaseMessagingService>().requestPermission();
```

For the UX it is better to call it once, on the user's authorization or
registration.

## Local notifications

Based on [awesome_notifications](https://pub.dev/packages/awesome_notifications).

Used only on **Android**: they show the pushes received in the **Foreground**
state. Title, body and image are supported.

### Notification channel (`channelKey`)

On Android a push is shown by two different mechanisms, depending on the
application state:

* **Foreground** — by this package via `awesome_notifications`, on the channel
  created here;
* **Background / Terminated** — by FCM itself, on the channel declared in the
  app manifest as `com.google.firebase.messaging.default_notification_channel_id`.

For both to use the same **high-importance** channel and show a heads-up
banner, the `channelKey` passed to `prepare` **must exactly match** the
manifest value. If they differ, FCM falls back to a default-importance channel
and pushes arrive without a banner.

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="app-notifications" />
```

Keep the key the same across flavors: channels are per-app, so flavors with
different `applicationId`s do not clash. When `channelKey` is omitted, the
legacy `'<name>-notifications'` key is used for backward compatibility.

### Small icon (`icon`)

Android draws the small icon of the status bar and of the notification by its
alpha channel only, as a white (then tinted) silhouette. Provide a dedicated
**monochrome** drawable (transparent background + white shape). Otherwise the
launcher icon is taken and shows as a white blob, or does not show at all on
some vendors' devices (Xiaomi/MIUI).

Pass it as `icon: 'resource://drawable/ic_stat_notification'` for the
foreground path, and declare the same drawable in the manifest for the FCM
background path:

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_icon"
  android:resource="@drawable/ic_stat_notification" />
```

When `icon` is omitted, the application launcher icon is used.
