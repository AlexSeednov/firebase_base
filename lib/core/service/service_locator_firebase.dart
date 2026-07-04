import 'package:injectable/injectable.dart';

/// Injectable micro-package module.
///
/// build_runner collects every `@injectable` service of the package into
/// `service_locator_firebase.module.dart` (the `FirebaseBasePackageModule`
/// class). Consumers wire it via `externalPackageModulesBefore` in their
/// `@InjectableInit` — there is no manual registration
/// (`ServiceLocatorFirebase.prepare`) anymore; getIt is the single source of
/// singleton ownership.
@InjectableInit.microPackage()
void initFirebaseBasePackage() {}
