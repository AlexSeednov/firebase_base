## 0.2.8

* **Crashlytics collection is switched back on with `isCrashlyticsEnabled:
  true`.** `isCrashlyticsEnabled: false` writes the SDK's collection flag
  off, and the SDK keeps that flag across launches, but the `true` branch
  never wrote it back. An application that came back to Crashlytics had its
  handlers bound to a collector that silently dropped every report, while the
  README promised the opposite. `CrashlyticsService.prepare` now enables
  collection unconditionally, as `disable` has always disabled it. An
  application that never turned Crashlytics off sees no difference.

* **Unhandled asynchronous errors show in the debug console.**
  `PlatformDispatcher.onError` returns `true`, which mutes the engine's own
  print, and the report went to the SDK without printing either: in debug such
  an error appeared nowhere. It is logged by hand now, in debug only — outside
  it the logger would report the error a second time.

* **`FirebaseMessagingService.requestPermission` never throws.** A failed
  request escaped to the caller, and an application that calls it unawaited
  got an unhandled error, which the crash reporter counts as a crash. The
  failure is logged now and answered with `AuthorizationStatus.notDetermined`,
  as a call before `prepare` already was.

* **A failure to read the push that launched the application is logged.**
  `getInitialMessage` runs unawaited in `prepare`, so its failure escaped as an
  unhandled error and was counted as a crash.

* **Crashlytics log time stamps are pinned to `en_US`**, like the date next to
  them. `DateFormat.Hms()` took the locale current when the service was
  created. Today that happens before the interface locale is resolved, but a
  service created later would stamp in the interface language — or throw,
  had that locale's date symbols not been loaded yet.

* **README in Russian** — `README.ru.md`, a full translation of `README.md`,
  with a language switcher at the top of both. The English file stays the
  source of truth, and every README change is made in both files at once.

* **README brought up to date**: the installation snippet shows the current
  version and no longer lists the web as unsupported, the `firebase_core`
  constraint matches the package's own, and the foreground-push advice for
  Android points to the package's own local notifications instead of a
  different plugin.

* **README edited for readability, in both languages.** Methods are written
  as `FirebaseBase.prepare`, not `FirebaseBase -> prepare`; *Usage* goes in
  the order an application follows (dependency, module, `prepare`), names the
  four services and says what `prepare` returns; the Crashlytics flag and the
  messaging section are split into short paragraphs, with sub-headings for
  the token, the payload and the permission. The Russian text is rewritten
  the same way, without the calques it had picked up in translation.

* **Every comment in the package reviewed** — `lib/`, `pubspec.yaml` and
  `analysis_options.yaml`. Comments that retold the code are gone, wordy ones
  are cut down to the reason they carry, and the missing reasons are added:
  why `pushSubject` replays the latest payload to a new listener, why the
  Crashlytics flag is written on every launch, why a notification id comes
  from the message. Comments that contradicted the code are corrected — the
  foreground listener was described as a tap on a push, while it handles a
  push that arrives. No code changes.

## 0.2.7

* **`application_base` constraint widened to `>=0.3.0 <0.5.0`.** The caret
  stopped at 0.4.0, so an application that had moved to the new minor line
  could not resolve this package at all. Nothing here uses anything past
  0.3.0, and both lines in use across the applications now resolve.

## 0.2.6

* Updates **Application Base** to version 0.3.0 (adds
  `UrlLauncher.launchLinkInSameTab`; nothing in this package changes). Without
  the widened constraint any consumer of both packages could not resolve its
  dependency graph: the previous `^0.2.8` excluded application_base 0.3.0.

## 0.2.5

* Web support: the package now compiles and launches on web.
  `firebase_crashlytics` has no web implementation and previously broke the
  web build of any consumer; its SDK calls are isolated behind a conditional
  import (`CrashlyticsReporter`) and replaced with a silent no-op on web.

* `FirebaseService.prepare` skips initialization on web when no explicit
  `FirebaseOptions` are passed (there is no native config file to read them
  from), `FirebaseMessagingService.prepare` skips messaging on web until FCM
  Web Push (service worker + VAPID key) is wired, and `requestPermission`
  reports the skip with an info instead of an error. See the new "Web support"
  section in the README for the full list of limitations.

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
