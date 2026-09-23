[English](README.md) | **Русский**

Единая базовая интеграция Firebase для Flutter-приложений на основе
[пакета application_base](https://github.com/AlexSeednov/application_base)
с [особой архитектурой](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014).

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
[awesome_notifications](https://pub.dev/packages/awesome_notifications).

## Поддержка веба

В вебе пакет собирается и работает, но умеет меньше:

* **Firebase Core** инициализируется, только если в `FirebaseBase.prepare`
  явно переданы `FirebaseOptions`: в вебе нет нативного конфигурационного
  файла, из которого их можно прочитать. Без них весь стек Firebase
  пропускается, в лог пишется info-строка.
* **Crashlytics** FlutterFire в вебе не поддерживает вовсе, плагин там даже
  не собирается. Внутри пакета SDK спрятан за условным импортом
  (`CrashlyticsReporter`) и в вебе заменён пустой заглушкой. Глобальные
  обработчики ошибок и удалённый логгер при этом работают как обычно.
* **Cloud Messaging** в вебе технически возможен (FCM Web Push), но пока не
  реализован. Для него нужны service worker `firebase-messaging-sw.js` в
  приложении и VAPID-ключ для `getToken`. Пока `prepare` пропускает messaging
  в вебе с info-строкой в логе. Стоит помнить и об ограничениях браузера:
  пуши показывает он сам, а Safari на iOS доставляет их только в PWA,
  установленное на домашний экран.
* **Локальные уведомления** нужны только на Android в foreground-сценарии,
  в вебе `awesome_notifications` не задействован.

## Требования

Определяются минимальными требованиями
[пакета application_base](https://github.com/AlexSeednov/application_base).

## История изменений

Все примечания к релизам смотрите в
[Changelog](https://github.com/AlexSeednov/firebase_base/blob/main/CHANGELOG.md).

## Использование

1. Добавьте в `pubspec.yaml` приложения запись вроде этой (и выполните
   `flutter pub get`):

```yaml
  # Not supported: Linux | macOS | Windows
  firebase_base:
    git:
      url: https://github.com/AlexSeednov/firebase_base
      tag_pattern: v{{version}}
    version: 0.2.8
```

2. Подключите injectable-модуль пакета к своему сервис-локатору:

```dart
import 'package:firebase_base/core/service/service_locator_firebase.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(FirebaseBasePackageModule)],
)
Future<void> configureDependencies() => getIt.init();
```

3. При запуске дождитесь инициализации DI и затем вызовите
   `FirebaseBase.prepare`:

```dart
await configureDependencies();
await FirebaseBase.prepare(name: applicationName);
```

`applicationName` — имя приложения, под которым его уведомления показываются
в системных настройках Android.

Порядок важен. Когда подключены внешние модули пакетов, `getIt.init()`
становится асинхронным, поэтому вызывайте его с **await**.
`FirebaseBase.prepare` берёт сервисы из getIt, поэтому должен выполняться
**после** того, как `getIt.init()` завершился.

`prepare` возвращает `bool`: запустилось ли всё. Исключений он не бросает:
сломанная настройка Firebase ограничивает приложение, а не блокирует его
запуск, и что делать без Firebase, решает вызывающая сторона. Без Firebase
Core messaging не запускается.

На **Android** можно передать ещё два необязательных параметра: канал
уведомлений и иконку в строке состояния (см.
[Локальные уведомления](#локальные-уведомления)):

```dart
await FirebaseBase.prepare(
  name: applicationName,
  channelKey: 'app-notifications',                  // must match the manifest
  icon: 'resource://drawable/ic_stat_notification', // monochrome small icon
);
```

Сервисов в пакете четыре: `FirebaseService`, `CrashlyticsService`,
`FirebaseMessagingService` и `LocalNotificationsService`. Все они синглтоны,
жизненным циклом которых владеет getIt, регистрирует их injectable-модуль
пакета (`@lazySingleton`). Берите их через `getIt<T>()` или через конструктор.

## Firebase Core

На базе [firebase_core](https://pub.dev/packages/firebase_core).

Всё необходимое инициализирует `FirebaseBase.prepare`. Если нужны
собственные параметры проекта Firebase, передайте в него `FirebaseOptions`.
Пакет `firebase_core` при этом должен быть и в `pubspec.yaml` приложения:

```yaml
  # https://pub.dev/packages/firebase_core
  firebase_core: ^4.11.0
```

## Firebase Crashlytics

На базе [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics).

Всё необходимое инициализирует `FirebaseBase.prepare`.

Если приложение отправляет краши через другой инструмент, отключите
Crashlytics, сохранив остальной Firebase:

```dart
await FirebaseBase.prepare(
  name: applicationName,
  isCrashlyticsEnabled: false,
);
```

Что при этом происходит:

* Флаг не просто пропускает установку Dart-обработчиков. Нативный SDK
  начинает сбор данных вместе с `Firebase.initializeApp`, поэтому пакет
  дополнительно вызывает `setCrashlyticsCollectionEnabled(false)`. Иначе
  нативные краши продолжали бы уходить в Firebase после того, как приложение
  от него отказалось.
* Настройка сохраняется между запусками. Приложению, которое вернётся к
  Crashlytics, достаточно снова передать `true`: эта ветка включает сбор
  обратно.
* В iOS-проекте уберите и фазу сборки *Crashlytics Upload Symbols*, иначе
  сборка продолжит загружать dSYM-файлы в проект, который никто не читает.

## Firebase Cloud Messaging

На базе [firebase_messaging](https://pub.dev/packages/firebase_messaging).

Инструкция по настройке Firebase:
[здесь](https://firebase.google.com/docs/cloud-messaging/flutter/client).

Как показывается сообщение, зависит от состояния приложения и ОС. Состояния
приложения:

* **Foreground** — приложение открыто, видно на экране и используется.
* **Background** — приложение открыто, но в фоне (свёрнуто). Обычно так
  бывает, когда пользователь нажал кнопку «Домой», переключился на другое
  приложение через переключатель или открыл приложение в другой вкладке
  (веб).
* **Terminated** — устройство заблокировано или приложение не запущено.

Чтобы пуш показывался в **Foreground**, нужна подготовка:

* На **Android** FCM не показывает уведомление, пришедшее, пока приложение
  на переднем плане. Пакет показывает его сам, локальным уведомлением на
  канале с высокой важностью, см.
  [Локальные уведомления](#локальные-уведомления).
* На **iOS** параметры показа задаются через
  `FirebaseMessaging.setForegroundNotificationPresentationOptions`.

Подробности в
[документации Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/receive),
схема с общей картиной
[здесь](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png).

### Токен и payload

FCM-токен устройства даёт `FirebaseMessagingService.token`, на iOS рядом с
ним `apnsToken`:

```dart
getIt<FirebaseMessagingService>().token;
```

Данные из payload пуша приходят в стрим `pushSubject`. Payload — это
`Map<String, dynamic>`. Новый подписчик сразу получает предыдущий payload,
если он был:

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

### Разрешение на уведомления

Разрешение у пользователя запрашивает
`FirebaseMessagingService.requestPermission`:

```dart
final status = await getIt<FirebaseMessagingService>().requestPermission();
```

Для UX лучше вызывать его один раз, при авторизации или регистрации
пользователя.

## Локальные уведомления

На базе [awesome_notifications](https://pub.dev/packages/awesome_notifications).

Используются только на **Android**: показывают пуши, полученные в состоянии
**Foreground**. Поддерживаются заголовок, текст и изображение.

### Канал уведомлений (`channelKey`)

На Android пуш показывают два разных механизма, в зависимости от состояния
приложения:

* **Foreground** — этот пакет через `awesome_notifications`, на канале,
  который создаётся здесь же;
* **Background / Terminated** — сам FCM, на канале, объявленном в манифесте
  приложения как `com.google.firebase.messaging.default_notification_channel_id`.

Чтобы оба механизма использовали один канал с **высокой важностью** и
показывали всплывающий heads-up баннер, `channelKey`, переданный в `prepare`,
**должен в точности совпадать** со значением в манифесте. Если они
расходятся, FCM откатывается на канал с важностью по умолчанию, и пуши
приходят без баннера.

```xml
<!-- AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="app-notifications" />
```

Делайте ключ одинаковым для всех флейворов: каналы у каждого приложения
свои, поэтому флейворы с разными `applicationId` не конфликтуют. Если
`channelKey` не передан, для обратной совместимости используется устаревший
ключ `'<name>-notifications'`.

### Малая иконка (`icon`)

Малую иконку в строке состояния и в уведомлении Android рисует только по её
альфа-каналу, как белый (затем тонированный) силуэт. Подготовьте отдельный
**монохромный** drawable (прозрачный фон + белый рисунок). Иначе будет взята
иконка лаунчера, и она отобразится белым пятном, а на устройствах некоторых
производителей (Xiaomi/MIUI) не отобразится вовсе.

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
