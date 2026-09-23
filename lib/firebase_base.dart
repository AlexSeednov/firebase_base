import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/service/firebase_messaging_service.dart';
import 'package:firebase_base/core/service/firebase_service.dart';
// firebase_core declares a FirebaseService of its own; only FirebaseOptions is
// needed from it.
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;

/// Start-up of the package: Firebase core, Crashlytics, messaging and local
/// notifications.
abstract final class FirebaseBase {
  /// Call after the application's `getIt.init()`: the services are registered
  /// by the injectable module `FirebaseBasePackageModule`, wired through
  /// `externalPackageModulesBefore` of the application's `@InjectableInit`.
  ///
  /// **name** — application name, shown in the Android notification settings.
  ///
  /// **channelKey** — Android notification channel id. Must equal
  /// `com.google.firebase.messaging.default_notification_channel_id` in the
  /// application's `AndroidManifest.xml`, otherwise pushes received in the
  /// background or terminated state show no heads-up banner. Keep it the same
  /// for every flavor. `null` falls back to `'$name-notifications'`.
  ///
  /// **icon** — status bar icon of foreground notifications on Android, e.g.
  /// `'resource://drawable/ic_stat_notification'`. Must be monochrome (white
  /// on transparent). `null` falls back to the launcher icon.
  ///
  /// **options** — Firebase options of the current platform and flavor.
  ///
  /// **isCrashlyticsEnabled** — `false` when the application reports crashes
  /// through another tool: messaging keeps working, while Crashlytics stops
  /// collecting instead of duplicating every crash into a second dashboard.
  ///
  /// Returns whether every part started. Nothing here throws: a broken
  /// Firebase setup degrades the application instead of blocking its launch,
  /// and the caller decides what that means for it.
  static Future<bool> prepare({
    required String name,
    String? channelKey,
    String? icon,
    FirebaseOptions? options,
    bool isCrashlyticsEnabled = true,
  }) async {
    final bool isCoreReady = await getIt<FirebaseService>().prepare(
      options: options,
      isCrashlyticsEnabled: isCrashlyticsEnabled,
    );

    /// Messaging has nothing to attach to without the core
    if (!isCoreReady) return false;

    return getIt<FirebaseMessagingService>().prepare(
      name: name,
      channelKey: channelKey,
      icon: icon,
    );
  }
}
