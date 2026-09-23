[English](README.md) | **Русский**

Единая базовая интеграция Firebase для Flutter-приложений на основе
[пакета application_base](https://github.com/AlexSeednov/application_base)
с
[особой архитектурой](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014)

## Возможности

Сейчас пакет включает:
* [Firebase Core](#firebase-core)
* [Firebase Crashlytics](#firebase-crashlytics)
* [Firebase Cloud Messaging](#firebase-cloud-messaging)
* [Локальные уведомления](#локальные-уведомления)

## Поддерживаемые платформы

* Android
* iOS
* Web — собирается и запускается, но с ограничениями, см.
  [Поддержка веба](#поддержка-веба)

Остальные платформы не поддерживаются из-за
[awesome_notifications](https://pub.dev/packages/awesome_notifications)

## Поддержка веба

В вебе пакет собирается и работает, сводя функциональность к необходимому
минимуму:

* **Firebase Core** — инициализируется, только если в `FirebaseBase.prepare`
  явно переданы `FirebaseOptions`: в вебе нет нативного конфигурационного
  файла, из которого их можно было бы прочитать. Без них весь стек Firebase
  аккуратно пропускается (с info-логом).
* **Crashlytics** — FlutterFire в вебе его не поддерживает вовсе (плагин там
  даже не собирается). Внутри пакета SDK изолирован за условным импортом
  (`CrashlyticsReporter`) и в вебе подменяется молчаливой заглушкой (no-op);
  глобальные обработчики ошибок и удалённый логгер при этом остаются
  нетронутыми.
* **Cloud Messaging** — технически в вебе возможен (FCM Web Push), но пока не
  реализован: для него нужны service worker `firebase-messaging-sw.js` в
  приложении-потребителе и VAPID-ключ для `getToken`. Пока `prepare` в вебе
  пропускает messaging с info-логом. Ограничения на стороне браузера, которые
  стоит держать в голове: пуши показывает сам браузер, а Safari на iOS
  доставляет их только в PWA, установленное на домашний экран.
* **Локальные уведомления** — `awesome_notifications` используется только в
  foreground-сценарии на Android и в вебе не затрагивается вовсе.

## Требования

Определяются минимальными требованиями
[пакета application_base](https://github.com/AlexSeednov/application_base)

## История изменений

Все примечания к релизам смотрите в
[Changelog](https://github.com/AlexSeednov/firebase_base/blob/main/CHANGELOG.md)

## Использование

Добавьте в pubspec.yaml вашего пакета запись вроде этой (и выполните неявный
flutter pub get):

```yaml
  # Not supported: Linux | macOS | Windows
  firebase_base:
    git:
      url: https://github.com/AlexSeednov/firebase_base
      tag_pattern: v{{version}}
    version: 0.2.8
```

Теперь достаточно вызвать `FirebaseBase -> prepare` при запуске приложения,
чтобы инициализировать всё необходимое.

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
где `applicationName` — имя Android-приложения для системных настроек уведомлений.

Когда подключены внешние модули пакетов, `getIt.init()` становится
асинхронным, поэтому вызывайте его с **await**. `FirebaseBase.prepare`
резолвит зарегистрированные сервисы, поэтому он должен выполняться **после**
того, как `getIt.init()` завершился.

На **Android** можно также передать два необязательных параметра, которые
настраивают канал уведомлений и иконку в строке состояния (см.
[Локальные уведомления](#локальные-уведомления)):

```dart
await FirebaseBase.prepare(
  name: applicationName,
  channelKey: 'app-notifications',                  // must match the manifest
  icon: 'resource://drawable/ic_stat_notification', // monochrome small icon
);
```

Все четыре сервиса — синглтоны, жизненным циклом которых владеет getIt; их
регистрирует injectable-модуль пакета (`@lazySingleton`). Получайте их через
`getIt<T>()` или внедряйте через конструктор.

## Firebase Core

На базе [firebase_core](https://pub.dev/packages/firebase_core).

Всё необходимое инициализируется вызовом `FirebaseBase -> prepare`.
Но если нужно задать собственные параметры проекта Firebase, можно передать
`FirebaseOptions` в функцию `prepare`. Не забудьте добавить пакет
`firebase_core` в `pubspec.yaml`:

```yaml
  # https://pub.dev/packages/firebase_core
  firebase_core: ^4.11.0
```

## Firebase Crashlytics

На базе [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics).

Всё необходимое инициализируется вызовом `FirebaseBase -> prepare`.

Если приложение отправляет краши через другой инструмент, отключите
Crashlytics, сохранив остальной Firebase:

```dart
await FirebaseBase.prepare(
  name: applicationName,
  isCrashlyticsEnabled: false,
);
```

Флаг не просто пропускает установку Dart-обработчиков: нативный SDK начинает
сбор данных вместе с `Firebase.initializeApp`, поэтому пакет дополнительно
вызывает `setCrashlyticsCollectionEnabled(false)` — иначе нативные краши
продолжали бы уходить в Firebase и после того, как приложение от него
отказалось. Настройка сохраняется между запусками, поэтому приложению, которое
вернётся к Crashlytics, отправку восстановит ветка `true`. Уберите из
iOS-проекта и фазу сборки *Crashlytics Upload Symbols*, иначе сборка продолжит
загружать dSYM-файлы в проект, который никто не читает.

## Firebase Cloud Messaging

На базе [firebase_messaging](https://pub.dev/packages/firebase_messaging).

Инструкция по настройке Firebase — [здесь](https://firebase.google.com/docs/cloud-messaging/flutter/client)

Поведение сообщений зависит от состояния приложения и ОС.
Возможные состояния приложения:

* **Foreground** — приложение открыто, видно на экране и используется

* **Background** — приложение открыто, но находится в фоне
(свёрнуто). Обычно так бывает, когда пользователь нажал на устройстве кнопку
«Домой», переключился на другое приложение через переключатель приложений
или открыл приложение в другой вкладке (веб)

* **Terminated** — устройство заблокировано или приложение не запущено

В **Foreground** пуши показываются после некоторой подготовки:

* На **Android** FCM не показывает уведомление, пришедшее, пока приложение
на переднем плане. Пакет показывает его сам — локальным уведомлением на канале
с высокой важностью, см.
[Локальные уведомления](#локальные-уведомления)

* На **iOS** можно изменить параметры показа уведомлений для приложения через
`FirebaseMessaging -> setForegroundNotificationPresentationOptions`

Подробности — в [документации Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/receive)

Схема с общей картиной — [здесь](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png)

FCM-токен устройства доступен через **FirebaseMessagingService->token**.

Пример:

```dart
getIt<FirebaseMessagingService>().token;
```

Чтобы получить данные из payload пуша, подпишитесь на стрим `pushSubject`.
При подписке стрим сразу отдаст предыдущий payload, если он был.
Payload — `Map<String, dynamic>`

Пример:

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

**Важно:** не забудьте запросить у пользователя разрешение на уведомления через
`FirebaseMessagingService->requestPermission`.

Пример

```dart
final status = await getIt<FirebaseMessagingService>().requestPermission();
```

С точки зрения UX лучше вызывать его один раз — только при авторизации /
регистрации пользователя.


## Локальные уведомления

На базе [awesome_notifications](https://pub.dev/packages/awesome_notifications)

Используются только на **Android** — для показа пуш-уведомлений, полученных,
когда приложение находится в состоянии **Foreground**.

Поддерживаются заголовок, текст и изображение.

### Канал уведомлений (`channelKey`)

На Android пуш показывается двумя разными механизмами в зависимости от
состояния приложения:

* **Foreground** — этим пакетом через `awesome_notifications`, в канале,
который создаётся здесь же;
* **Background / Terminated** — самим FCM, в канале, объявленном в манифесте
приложения как `com.google.firebase.messaging.default_notification_channel_id`.

Чтобы оба механизма использовали один и тот же канал с **высокой важностью**
(а значит, показывали всплывающий heads-up баннер), `channelKey`, переданный
в `prepare`, ОБЯЗАН в точности совпадать со значением в манифесте. Если они
расходятся, FCM откатывается на канал с важностью по умолчанию, и пуши
приходят без баннера. Делайте ключ независимым от флейвора — каналы у каждого
приложения свои, поэтому разные флейворы (с разными `applicationId`) не
конфликтуют.

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="app-notifications" />
```

Если `channelKey` не передан, для обратной совместимости используется
устаревший ключ `'<name>-notifications'`.

### Малая иконка (`icon`)

Малую иконку в строке состояния и в уведомлении Android отрисовывает только по
её альфа-каналу — как белый (а затем тонированный) силуэт. Подготовьте
отдельный **монохромный** (прозрачный + белый) drawable, иначе будет
использована иконка лаунчера, и она отобразится белым пятном (а на устройствах
некоторых производителей, например Xiaomi/MIUI, не отобразится вовсе).

Передайте её как `icon: 'resource://drawable/ic_stat_notification'` для
foreground-сценария и объявите тот же drawable в манифесте для фонового
сценария FCM:

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_icon"
  android:resource="@drawable/ic_stat_notification" />
```

Если `icon` не передан, используется иконка приложения из лаунчера.
