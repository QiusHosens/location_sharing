import mqtt from 'mqtt';

let mqttClient: mqtt.MqttClient | null = null;

export function connectMqtt(userId: string, onLocationUpdate: (data: any) => void, onNotification: (data: any) => void) {
  const brokerUrl = import.meta.env.VITE_MQTT_URL || 'ws://www.synerunify.com:40803/mqtt';

  mqttClient = mqtt.connect(brokerUrl, {
    clientId: `web_${userId}_${Date.now()}`,
    clean: true,
    reconnectPeriod: 5000,
  });

  mqttClient.on('connect', () => {
    console.log('MQTT connected');
    mqttClient?.subscribe(`location/${userId}/realtime`);
    mqttClient?.subscribe(`notification/${userId}`);
  });

  mqttClient.on('message', (topic, payload) => {
    try {
      const data = JSON.parse(payload.toString());
      if (topic.includes('/realtime')) onLocationUpdate(data);
      else if (topic.includes('notification/')) onNotification(data);
    } catch (e) {
      console.error('MQTT message parse error', e);
    }
  });

  mqttClient.on('error', (err) => console.error('MQTT error:', err));
  return mqttClient;
}

export function subscribeFamilyLocations(userIds: string[], onUpdate: (data: any) => void) {
  if (!mqttClient) return;
  userIds.forEach((uid) => {
    mqttClient?.subscribe(`location/${uid}/realtime`);
  });
}

export function disconnectMqtt() {
  mqttClient?.end();
  mqttClient = null;
}
