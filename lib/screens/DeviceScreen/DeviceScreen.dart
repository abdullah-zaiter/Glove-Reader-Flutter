import 'dart:math';

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:glove_reader/components/CharacteristicTile/CharacteristicTile.dart';
import 'package:glove_reader/components/DescriptorTile/DescriptorTile.dart';
import 'package:glove_reader/components/ServiceTile/ServiceTile.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [00, 01];
  }

  void writeToCsv(List<List<int>> data) async {
    debugPrint("writeToCsv");
    String csv = const ListToCsvConverter().convert(data);
    final Directory directory = Directory('/storage/emulated/0/Glove-Reader');
    final status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    directory.create(recursive: true).then((Directory directory) async {
      final File file = File('${directory.path}/data.csv');
      await file.writeAsString(csv);
      debugPrint("done writing");
      debugPrint("path: ${directory.path}");
    });
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
                      await c.write(_getRandomBytes());
                      final data = await c.read();
                      debugPrint("here test test");
                      debugPrint(data.toString());
                      writeToCsv([data]);
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(34),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
