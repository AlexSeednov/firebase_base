//@GeneratedMicroModule;FirebaseBasePackageModule;package:firebase_base/core/service/service_locator_firebase.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:firebase_base/core/service/crashlytics_service.dart' as _i735;
import 'package:firebase_base/core/service/firebase_messaging_service.dart'
    as _i570;
import 'package:firebase_base/core/service/firebase_service.dart' as _i466;
import 'package:firebase_base/core/service/local_notifications_service.dart'
    as _i35;
import 'package:injectable/injectable.dart' as _i526;

class FirebaseBasePackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i735.CrashlyticsService>(
        () => _i735.CrashlyticsService());
    gh.lazySingleton<_i570.FirebaseMessagingService>(
        () => _i570.FirebaseMessagingService());
    gh.lazySingleton<_i466.FirebaseService>(() => _i466.FirebaseService());
    gh.lazySingleton<_i35.LocalNotificationsService>(
        () => _i35.LocalNotificationsService());
  }
}
