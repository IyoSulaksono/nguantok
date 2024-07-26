import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:oscilloscope/oscilloscope.dart';

import 'data.dart';

import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  //List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;

  List<double> data = [];
  int blink = 0;
  double dt = 0;
  double dt1 = 0;
  double totaldt = 0;
  double avg = 0;

  double radians = 0.0;
  Timer? _timer;

  //TextEditingController _textController = TextEditingController();

  Future<bool> _connectTo(device) async {
    //_serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        List<String> temp = line.split(',');
        radians = double.parse(temp[0]);
        blink = int.parse(temp[1]);
        dt = double.parse(temp[2]);
        totaldt = totaldt + dt;
        avg = totaldt / blink;
        if (dt != 0) {
          dt1 = dt;
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    print(devices);

    devices.forEach((device) {
      _ports.add(ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName!),
          subtitle: Text(device.manufacturerName!),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    });

    setState(() {
      print(_ports);
    });
  }

  _generateTrace(Timer t) {
    // generate our  values

    // Add to the growing dataset
    setState(() {
      data.add(radians);
    });

    // adjust to recyle the radian value ( as 0 = 2Pi RADS)
    radians += 0.05;
    if (radians >= 2.0) {
      radians = 0.0;
    }
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();

    _timer = Timer.periodic(Duration(milliseconds: 60), _generateTrace);
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
    _timer!.cancel();
  }

  @override
  Widget build(BuildContext context) {
    Oscilloscope scopeOne = Oscilloscope(
      showYAxis: true,
      yAxisColor: Colors.black45,
      margin: EdgeInsets.all(20.0),
      strokeWidth: 1.0,
      backgroundColor: Colors.white,
      traceColor: Colors.blue,
      yAxisMax: 500.0,
      yAxisMin: -100.0,
      dataSet: data,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nguantok'),
      ),
      body: Center(
          child: Column(
        children: <Widget>[
          Text(
              _ports.length > 0
                  ? "Available Serial Ports"
                  : "No serial devices available",
              style: Theme.of(context).textTheme.headline6),
          ..._ports,
          Text('Status: $_status\n'),
          Text('info: ${_port.toString()}\n'),
          SizedBox(height: 20),
          Text(
            "STATUS",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 5,
            ),
            textAlign: TextAlign.center,
          ),
          Expanded(flex: 1, child: scopeOne),
          Column(
            children: [
              Row(
                children: <Widget>[
                  Expanded(
                      child: Text(
                    "Jumlah Kedipan",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  )),
                  Expanded(
                      child: Text(
                    "Rata-rata PERCLOS",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  )),
                ],
              ),
              SizedBox(
                height: 30,
              ),
              Row(
                children: <Widget>[
                  Expanded(
                      child: Text(
                    "$blink",
                    style: TextStyle(
                      fontSize: 25,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  )),
                  Expanded(
                      child: Text(
                    "$dt",
                    style: TextStyle(
                      fontSize: 25,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  )),
                ],
              ),
            ],
          ),
          SizedBox(
            height: 30,
          ),
        ],
      )),
    );
  }
}
