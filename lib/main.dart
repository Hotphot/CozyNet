import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController homeController = TextEditingController();

  void navigateToHome() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          userName: nameController.text,
          homeName: homeController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Enter your name",
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: homeController,
                decoration: const InputDecoration(
                  labelText: "Enter your home name",
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: navigateToHome,
                child: const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final String homeName;

  const HomeScreen({super.key, required this.userName, required this.homeName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, bool> buttonStates = {
    "LIGHTING": false,
    "TEMP": false,
    "DOORBELL": false,
    "TV": false,
    "COFFEE": false,
    "CURTAINS": false,
  };

  late MQTTService mqttService;

  @override
  void initState() {
    super.initState();
    mqttService = MQTTService();
    mqttService.connect();
  }

  void toggleLight() {
    setState(() {
      buttonStates["LIGHTING"] = !buttonStates["LIGHTING"]!;
    });

    String state = buttonStates["LIGHTING"]! ? "on" : "off";
    print('Toggling light to $state');
    mqttService.sendMqttMessage('{ "state": "$state" }');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hi, ${widget.userName}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "You're in ${widget.homeName}'s home",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text(
              "Controllers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: buttonStates.keys.map((label) {
                  return GestureDetector(
                    onTap: () {
                      if (label == "LIGHTING") {
                        toggleLight();
                      } else {
                        setState(() {
                          buttonStates[label] = !buttonStates[label]!;
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: buttonStates[label]! ? Colors.white : Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            label == "LIGHTING"
                                ? LucideIcons.lightbulb
                                : label == "TEMP"
                                    ? LucideIcons.thermometer
                                    : label == "DOORBELL"
                                        ? LucideIcons.bell
                                        : label == "TV"
                                            ? LucideIcons.monitor
                                            : label == "COFFEE"
                                                ? LucideIcons.coffee
                                                : LucideIcons.blinds,
                            color: buttonStates[label]!
                                ? Colors.black
                                : Colors.white,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: TextStyle(
                              color: buttonStates[label]!
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MQTTService {
  String mqttBroker = '192.168.1.9';

  late MqttServerClient client;

  MQTTService() {
    if (Platform.isAndroid) {
      mqttBroker = '10.0.2.2';
      print('📡 Using Android Emulator, switching to broker: $mqttBroker');
    }
    client = MqttServerClient(mqttBroker, 'flutter_client');
  }

  Future<void> connect() async {
    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.logging(on: true);

    client.onDisconnected = () => print('❌ Disconnected from MQTT');
    client.onConnected = () => print('✅ Successfully connected to MQTT');

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .keepAliveFor(60)
        .startClean();

    client.connectionMessage = connMessage;

    try {
      print('🚀 Connecting to MQTT broker at $mqttBroker...');
      await client.connect();
      print('✅ Connected to MQTT!');
    } catch (e) {
      print('❌ MQTT connection failed: $e');
    }
  }

  void sendMqttMessage(String payload) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('⚠️ MQTT Not Connected! Trying to reconnect...');
      await connect();
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      client.publishMessage('tapo/bulb/set', MqttQos.atMostOnce, builder.payload!);
      print('📩 MQTT Message Sent: $payload');
    } else {
      print('❌ Failed to reconnect to MQTT, message not sent.');
    }
  }
}
