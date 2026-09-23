import 'package:injectable/injectable.dart';

/// Injectable micro-package module.
///
/// build_runner collects the package's services into
/// `service_locator_firebase.module.dart` (`FirebaseBasePackageModule`), and
/// an application wires it through `externalPackageModulesBefore` of its
/// `@InjectableInit`. getIt alone owns the singletons: nothing is registered
/// by hand.
@InjectableInit.microPackage()
void initFirebaseBasePackage() {}
