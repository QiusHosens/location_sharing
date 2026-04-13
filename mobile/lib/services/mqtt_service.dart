import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;
  Function(Map<String, dynamic>)? onLocationUpdate;
  Function(Map<String, dynamic>)? onNotification;

  Future<void> connect(String userId, {String host = '10.0.2.2', int port = 1883}) async {
    _client = MqttServerClient(host, 'flutter_\_\');
    _client!.port = port;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;

    try {
      await _client!.connect();
      _client!.subscribe('location/\/realtime', MqttQos.atLeastOnce);
      _client!.subscribe('notification/\', MqttQos.atLeastOnce);

      _client!.updates?.listen((messages) {
        for (final msg in messages) {
          final payload = MqttPublishPayload.bytesToStringAsString(
            (msg.payload as MqttPublishMessage).payload.message,
          );
          try {
            final data = jsonDecode(payload);
            if (msg.topic.contains('/realtime')) {
              onLocationUpdate?.call(data);
            } else if (msg.topic.contains('notification/')) {
              onNotification?.call(data);
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      print('MQTT connection error: \');
    }
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
