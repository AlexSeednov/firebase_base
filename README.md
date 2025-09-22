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

All other not supported because of 
[awesome_notifications](https://pub.dev/packages/awesome_notifications)

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
  # Not supported: Linux | MacOS | Web | Windows
  firebase_base:
    git:
      url: https://github.com/AlexSeednov/firebase_base
      tag_pattern: v{{version}}
    version: 0.1.3
```

Now just call `FirebaseBase -> prepare` on application launching to initialize 
all necessary data.

```dart
await FirebaseBase.prepare(name: applicationName);
```
where `applicationName` is Android application name for system notification setting.

All four services are **Singleton** and available via `GetIt`.

## Firebase Core

Based on [firebase_core](https://pub.dev/packages/firebase_core).

All necessary data will be initiated by using `FirebaseBase -> prepare`. 
But if you want to set custom Firebase project options, you can send an 
`FirebaseOptions` in `prepare` function. Do not forget to add 
`firebase_core` package in `pubspec.yaml`

```yaml
  # https://pub.dev/packages/firebase_core
  firebase_core: ^3.5.0
```

## Firebase Crashlytics

Based on [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics).

All necessary data will be initiated by using `FirebaseBase -> prepare`. 

## Firebase Cloud Messaging

Based on [firebase_messaging](https://pub.dev/packages/firebase_messaging).

Setup Firebase instruction [here](https://firebase.google.com/docs/cloud-messaging/flutter/client)

Messages have different behaviour depends on application state and OS.
Application state can be:

* **Foreground** - When the application is open, in view and in use

* **Background** - When the application is open, but in the background 
(minimized). This typically occurs when the user has pressed the "home" 
button on the device, has switched to another app using the app switcher, 
or has the application open in a different tab (web)

* **Terminated** - When the device is locked or the application is not running

In **Foreground** pushes will be shown after some preparations:

* On **Android**, you must create a "High Priority" notification channel,
but sometimes it doesn't work.. So it's better to use local notifications via
[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

* On **iOS**, you can update the presentation options for the application via 
`FirebaseMessaging -> setForegroundNotificationPresentationOptions`

Details in [Firebase docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive)

Sheme with common information [here](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png)

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

It's better for UX to call in once on user Authorization / Registration only.


## Local notifications

Based on [awesome_notifications](https://pub.dev/packages/awesome_notifications)

Used only on **Android** to show push notifications, got in **Foreground** 
application state.

Supports title, body and image.

