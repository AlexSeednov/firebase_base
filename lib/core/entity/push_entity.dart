import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:json_annotation/json_annotation.dart';

part 'push_entity.g.dart';

/// A received push. Serializable, so the Android foreground path can carry it
/// through a local notification's payload and read it back.
@JsonSerializable(createFactory: true, createToJson: true)
final class PushEntity {
  ///
  PushEntity();

  ///
  factory PushEntity.fromMessage(RemoteMessage message) => PushEntity()
    ..category = message.category
    ..from = message.from
    ..messageId = message.messageId
    ..messageType = message.messageType
    ..title = message.notification?.title ?? ''
    ..body = message.notification?.body ?? ''
    ..sentTime = message.sentTime
    ..contentAvailable = message.contentAvailable
    ..data = message.data;

  ///
  factory PushEntity.fromJson(Map<String, dynamic> json) =>
      _$PushEntityFromJson(json);

  /// Reverse of [toString].
  factory PushEntity.fromString(String data) =>
      PushEntity.fromJson(jsonDecode(data) as Map<String, dynamic>);

  ///
  @JsonKey(name: 'category')
  String? category;

  ///
  @JsonKey(name: 'from')
  String? from;

  ///
  @JsonKey(name: 'messageId')
  String? messageId;

  ///
  @JsonKey(name: 'messageType')
  String? messageType;

  ///
  @JsonKey(name: 'title')
  String? title;

  ///
  @JsonKey(name: 'body')
  String? body;

  ///
  @JsonKey(name: 'sentTime')
  DateTime? sentTime;

  ///
  @JsonKey(name: 'contentAvailable')
  bool? contentAvailable;

  ///
  @JsonKey(name: 'data')
  Map<String, dynamic>? data;

  ///
  Map<String, dynamic> toJson() => _$PushEntityToJson(this);

  /// JSON, so [PushEntity.fromString] can read it back.
  @override
  String toString() => json.encode(toJson());
}
