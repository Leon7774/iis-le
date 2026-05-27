import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleController extends ChangeNotifier {
  // BLE UUIDs for Nordic UART
  static const String uartServiceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String uartRxUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String uartTxUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? rxCharacteristic;
  BluetoothCharacteristic? txCharacteristic;

  bool isScanning = false;
  bool isConnecting = false;
  bool isConnected = false;

  String currentSpeed = "80%";
  String activeMode = "RC";
  List<bool> sensorsState = [false, false, false, false, false];
  List<String> consoleLogs = [];

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _txSubscription;
  StreamSubscription? _adapterStateSubscription;

  BleController() {
    // Listen to adapter state (e.g. bluetooth on/off)
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      logToConsole("Bluetooth adapter state: $state");
      if (state != BluetoothAdapterState.on) {
        disconnect();
      }
    });

    // Listen to scanning status
    FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });
  }

  void logToConsole(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    consoleLogs.insert(0, "[$timestamp] $message");
    if (consoleLogs.length > 50) {
      consoleLogs.removeLast();
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    if (isScanning || isConnecting || isConnected) return;

    logToConsole("Starting BLE scan...");
    
    // Check adapter state
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      logToConsole("Error: Bluetooth is turned off.");
      return;
    }

    try {
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.device.advName;
          if (name == "PicoMotor") {
            logToConsole("Found PicoMotor! Connecting...");
            FlutterBluePlus.stopScan();
            connectToDevice(r.device);
            break;
          }
        }
      }, onError: (e) {
        logToConsole("Scan error: $e");
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      logToConsole("Failed to start scan: $e");
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    isConnecting = true;
    notifyListeners();

    try {
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          isConnected = true;
          isConnecting = false;
          logToConsole("Connected to ${device.platformName.isNotEmpty ? device.platformName : 'PicoMotor'}");
          notifyListeners();
        } else if (state == BluetoothConnectionState.disconnected) {
          disconnect();
          logToConsole("Disconnected from device.");
        }
      });

      await device.connect(autoConnect: false, license: License.free);
      connectedDevice = device;

      // Discover services
      logToConsole("Discovering services...");
      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? uartService;

      for (var s in services) {
        if (s.uuid.toString() == uartServiceUuid) {
          uartService = s;
          break;
        }
      }

      if (uartService == null) {
        logToConsole("Error: Nordic UART Service not found on device.");
        disconnect();
        return;
      }

      for (var c in uartService.characteristics) {
        if (c.uuid.toString() == uartRxUuid) {
          rxCharacteristic = c;
          logToConsole("Found RX Characteristic (Write)");
        } else if (c.uuid.toString() == uartTxUuid) {
          txCharacteristic = c;
          logToConsole("Found TX Characteristic (Notify)");
        }
      }

      if (rxCharacteristic != null && txCharacteristic != null) {
        // Enable notifications on TX
        await txCharacteristic!.setNotifyValue(true);
        _txSubscription?.cancel();
        _txSubscription = txCharacteristic!.lastValueStream.listen((value) {
          final reply = utf8.decode(value);
          if (reply.startsWith("SENS:")) {
            final data = reply.replaceAll("SENS:", "").trim();
            final parts = data.split(",");
            if (parts.length == 5) {
              sensorsState = parts.map((p) => p == "1").toList();
              notifyListeners();
            }
          } else {
            logToConsole("Pico -> App: ${reply.trim()}");
            if (reply.startsWith("SPD:")) {
              currentSpeed = reply.replaceAll("SPD:", "").trim();
              notifyListeners();
            } else if (reply.startsWith("MODE:")) {
              activeMode = reply.replaceAll("MODE:", "").trim();
              notifyListeners();
            }
          }
        });
        logToConsole("BLE communication initialized successfully!");
      } else {
        logToConsole("Error: RX/TX characteristics not found.");
        disconnect();
      }

    } catch (e) {
      logToConsole("Connection failed: $e");
      disconnect();
    }
  }

  Future<void> setMode(String mode) async {
    if (!isConnected) {
      logToConsole("Cannot change mode: Device not connected.");
      return;
    }
    logToConsole("App -> Pico: Requesting mode $mode");
    if (mode == "RC") {
      await sendCommand("M:RC");
    } else if (mode == "LINE") {
      await sendCommand("M:LINE");
    }
  }

  Future<void> sendCommand(String cmd) async {
    if (rxCharacteristic == null || !isConnected) {
      logToConsole("Cannot send command: Device not connected.");
      return;
    }

    try {
      logToConsole("App -> Pico: $cmd");
      await rxCharacteristic!.write(utf8.encode(cmd), withoutResponse: true);
    } catch (e) {
      logToConsole("Failed to send command $cmd: $e");
    }
  }

  Future<void> disconnect() async {
    _txSubscription?.cancel();
    _connectionSubscription?.cancel();
    
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        // Already disconnected or failed
      }
    }

    connectedDevice = null;
    rxCharacteristic = null;
    txCharacteristic = null;
    isConnected = false;
    isConnecting = false;
    activeMode = "RC";
    notifyListeners();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _txSubscription?.cancel();
    super.dispose();
  }
}
