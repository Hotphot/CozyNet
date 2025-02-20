import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: LoginScreen(),
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
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Enter your name",
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: homeController,
                decoration: InputDecoration(
                  labelText: "Enter your home name",
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: navigateToHome,
                child: Text("Login"),
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

  double lightIntensity = 50.0;
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
    mqttService.sendMqttMessage('{ "state": "$state" }');
  }

  void showLightIntensityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Adjust Light Intensity"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: lightIntensity,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: "${lightIntensity.round()}%",
                    onChanged: (value) {
                      setDialogState(() {
                        lightIntensity = value;
                      });
                      setState(() {});
                      mqttService.sendMqttMessage('{ "state": "brightness:$value" }');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hi, ${widget.userName}",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "You're in ${widget.homeName}'s home",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            Text(
              "Controllers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: buttonStates.keys.map((label) {
                  return GestureDetector(
                    onTap: () {
                      if (label == "LIGHTING") {
                        if (!buttonStates[label]!) {
                          showLightIntensityDialog();
                        }
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
                            label == "LIGHTING" ? LucideIcons.lightbulb :
                            label == "TEMP" ? LucideIcons.thermometer :
                            label == "DOORBELL" ? LucideIcons.bell :
                            label == "TV" ? LucideIcons.monitor :
                            label == "COFFEE" ? LucideIcons.coffee :
                            LucideIcons.blinds,
                            color: buttonStates[label]! ? Colors.black : Colors.white,
                          ),
                          SizedBox(height: 5),
                          Text(label, style: TextStyle(color: buttonStates[label]! ? Colors.black : Colors.white)),
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
  final MqttServerClient client =
      MqttServerClient('192.168.1.50', 'flutter_client');

  Future<void> connect() async {
    client.port = 1883;
    client.keepAlivePeriod = 60;
    try {
      await client.connect();
      print('✅ Connected to MQTT broker');
    } catch (e) {
      print('❌ MQTT connection failed: $e');
    }
  }

  void sendMqttMessage(String payload) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage('tapo/bulb/set', MqttQos.atLeastOnce, builder.payload!);
  }
}
