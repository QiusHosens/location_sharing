import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../app_logger.dart';

class MqttService {
  MqttServerClient? _client;
  Function(Map<String, dynamic>)? onLocationUpdate;
  Function(Map<String, dynamic>)? onNotification;

  Future<void> connect(String userId, {String host = 'www.synerunify.com', int port = 41883}) async {
    final clientId = 'flutter_${userId.hashCode & 0x7fffffff}';
    _client = MqttServerClient(host, clientId);
    _client!.port = port;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;

    try {
      await _client!.connect();
      // 与后端发布的 topic 一致：location/{userId}/update
      _client!.subscribe('location/$userId/update', MqttQos.atLeastOnce);
      _client!.subscribe('notification/$userId', MqttQos.atLeastOnce);

      _client!.updates?.listen((messages) {
        for (final msg in messages) {
          final payload = MqttPublishPayload.bytesToStringAsString(
            (msg.payload as MqttPublishMessage).payload.message,
          );
          try {
            final data = jsonDecode(payload);
            if (msg.topic.contains('location/') && msg.topic.contains('/update')) {
              onLocationUpdate?.call(data);
            } else if (msg.topic.contains('notification/')) {
              onNotification?.call(data);
            }
          } catch (_) {}
        }
      });
    } catch (e, st) {
      appLogger.e('MQTT connection error', error: e, stackTrace: st);
    }
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
