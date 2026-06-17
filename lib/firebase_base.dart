import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/service/firebase_messaging_service.dart';
import 'package:firebase_base/core/service/firebase_service.dart';
import 'package:firebase_base/core/service/service_locator_firebase.dart';
// Hide firebase_core's FirebaseService to avoid a name clash with this
// package's own FirebaseService; only FirebaseOptions is needed from here.
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;

abstract final class FirebaseBase {
  /// **name** - Android application name for system notification settings
  ///
  /// **channelKey** - stable Android notification channel id. It MUST match
  /// `com.google.firebase.messaging.default_notification_channel_id` in the
  /// app's `AndroidManifest.xml`, otherwise pushes received in
  /// Background/Terminated state are shown without a heads-up banner. Keep it
  /// flavor-independent. `null` falls back to the legacy
  /// `'$name-notifications'` key.
  ///
  /// **icon** - small (status bar) icon resource for foreground notifications
  /// on Android, e.g. `'resource://drawable/ic_stat_notification'`. Must be a
  /// monochrome (transparent + white) asset. `null` falls back to the
  /// application launcher icon.
  ///
  /// **options** - Specific Firebase configuration options depends on current
  /// platform and flavor
  static Future<void> prepare({
    required String name,
    String? channelKey,
    String? icon,
    FirebaseOptions? options,
  }) async {
    /// Setup service locator
    ServiceLocatorFirebase.prepare();

    /// Prepare all Firebase packages
    await getIt<FirebaseService>().prepare(options: options);

    ///
    await getIt<FirebaseMessagingService>().prepare(
      name: name,
      channelKey: channelKey,
      icon: icon,
    );
  }
}
