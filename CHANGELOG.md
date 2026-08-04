## 0.2.4

* Local Notifications - the notification channel named a channel group that was
  never registered, so every Android launch logged an error-level "Channel
  group ... does not exist" with a full stack trace. Nothing broke: the native
  side registers the exception, drops the grouping and creates the channel
  anyway, so the only real effects were the noise in the logs and a channel
  left ungrouped in the system notification settings. The group is now passed
  to `initialize` alongside the channel.

## 0.2.3

* `FirebaseBase.prepare` takes `isCrashlyticsEnabled`, so an application that
  reports crashes elsewhere can keep messaging and drop crash reporting.
  Previously `FirebaseService.prepare` installed the Crashlytics handlers
  unconditionally and the two were inseparable — every crash was paid for
  twice and split across two dashboards.

* Turning the flag off does not merely skip the handlers: `CrashlyticsService`
  gained `disable()`, which calls `setCrashlyticsCollectionEnabled(false)`. The
  native SDK begins collecting together with `Firebase.initializeApp`, so
  without the explicit opt-out native crashes kept reaching Firebase while the
  app believed it had left. The setting persists between launches, which is why
  it is written on every start rather than once.

* Updates **Application Base** to version 0.2.8. `CrashlyticsService` already
  declared the stack trace parameter its error sink now officially receives, so
  the trace reaches `recordError` instead of the synthesised date-only trace
  whenever the caller supplies one.

## 0.2.2

* Updates **Application Base** to version 0.2.7 and adopts its refreshed
  analyzer rule set
* Firebase Messaging - `dispose` now cancels the foreground, token-refresh and
  message-opened subscriptions instead of only closing `pushSubject`, and is
  annotated with `@disposeMethod`, so getIt actually calls it on a container
  reset. Previously the listeners survived the reset and stacked up
* Firebase Messaging - `prepare` became idempotent: a repeated call is a no-op
  instead of installing a second set of listeners that handled every push twice
* Firebase Messaging - the messaging instance is no longer `late` and nullable
  at once; the force-unwraps are replaced by a guard that reports a missing
  `prepare` explicitly. `requestPermission` keeps returning `notDetermined`
* Local Notifications - releases its static tap handler on dispose; a push
  tapped after a container reset no longer reaches the previous service
* Firebase Service - `prepare` no longer lets a failed `Firebase.initializeApp`
  escape: a missing or malformed native configuration now costs the application
  its telemetry instead of its launch. Crashlytics handlers are installed only
  after a successful initialization
* `FirebaseBase.prepare` returns whether every part started up (previously the
  messaging result was dropped) and skips messaging when the core failed
* Local Notifications - a foreground notification id is derived from the FCM
  message id instead of the entity's identity hash, so a redelivered push
  updates its banner instead of stacking a duplicate next to it
* Local Notifications - `show` before `prepare` logs and returns `false`
  instead of throwing a `LateInitializationError`
* Firebase Messaging - a failed foreground notification is logged instead of
  escaping as an unhandled asynchronous error, which the crash reporter used
  to count as a crash (an unreachable push image was enough to trigger it)
* Adds a CI workflow (format, analyze, codegen and DI-cycle checks)

## 0.2.1

* Updates minimum supported SDK version to Flutter 3.44.4/Dart 3.12.2
* Updates all packages to actual versions
* Migrates dependency injection to **injectable 3.x**: micro-packages are now
  registered exclusively via `externalPackageModulesBefore` /
  `externalPackageModulesAfter` (the removed `includeMicroPackages` mechanism).
  The package already wires `FirebaseBasePackageModule` this way, so its public
  API is unchanged — the generated `service_locator_firebase.module.dart` simply
  drops the legacy `//@GeneratedMicroModule` marker.
* Updates **Application Base** to version 0.2.4

## 0.2.0

* **BREAKING — DI moved to injectable.** The package now registers its own
  services (`FirebaseService`, `CrashlyticsService`, `FirebaseMessagingService`,
  `LocalNotificationsService`) through an injectable micro-package module
  (`FirebaseBasePackageModule` in `service_locator_firebase.module.dart`)
  instead of the manual `ServiceLocatorFirebase.prepare()` (class removed).
  Consumers wire it via
  `externalPackageModulesBefore: [ExternalModule(FirebaseBasePackageModule)]`
  in their `@InjectableInit`. `FirebaseBase.prepare()` no longer registers
  services — it only initializes them and must be called AFTER the consumer's
  `getIt.init()`.

## 0.1.9

* Firebase Messaging - optional `channelKey` parameter for the Android
  notification channel id
* Firebase Messaging - optional `icon` parameter for the foreground (Android)
  notification small icon

## 0.1.8

* Updates **Application Base** to version 0.2.0

## 0.1.7

* Improved fatal error logging

## 0.1.6

* Updates minimum supported SDK version to Flutter 3.38.7/Dart 3.10.7
* Updates all packages to actual versions
* Updates **Application Base** to version 0.1.6

## 0.1.5

* Firebase Messaging - getting tokens logging improved

## 0.1.4

* Firebase Messaging - getting tokens improved

## 0.1.3

* Updates **Application Base** to version 0.1.3
* Updates minimum supported SDK version to Flutter 3.35.4/Dart 3.9.2
* Updates all packages to actual versions
* Package versions store rebased from refs to tags

## 0.1.2

* Updates **Application Base** to version 0.1.2

## 0.1.1

* Updates **Application Base** to version 0.1.1
* Added **onTokenChanged** callback to **FirebaseMessagingService**
* Added **apnsToken** to **FirebaseMessagingService**

## 0.1.0

* Updates **Application Base** to version 0.1.0
* Updates minimum supported SDK version to Flutter 3.32.5/Dart 3.8.1
* Updates all packages to actual versions
  
## 0.0.9

* Updates **Application Base** to version 0.0.8

## 0.0.8

* Updates **Application Base** to version 0.0.7

## 0.0.7

* Updates minimum supported SDK version to Flutter 3.24.5/Dart 3.5.4
* Updates **Application Base** to version 0.0.6
* Updates dependencies

## 0.0.6

* Updates **Application Base** to version 0.0.5

## 0.0.5

* Updates **Application Base** to version 0.0.4

## 0.0.4

* Updates dependencies

## 0.0.3

* Updates **Application Base** to version 0.0.2

## 0.0.2

* **Local notifications** rebase on [awesome_notifications](https://pub.dev/packages/awesome_notifications)
* Image in push support added

## 0.0.1

* **Application Base** version 0.0.1 based on [application_base](https://github.com/AlexSeednov/application_base)
* **Firebase Core** based on [firebase_core](https://pub.dev/packages/firebase_core)
* **Firebase Crashlytics** based on [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics)
* **Firebase Cloud Messaging** based on [firebase_messaging](https://pub.dev/packages/firebase_messaging)
* **Local notifications** based on [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
