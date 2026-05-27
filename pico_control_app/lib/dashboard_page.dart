import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ble_controller.dart';

class DashboardPage extends StatefulWidget {
  final BleController controller;

  const DashboardPage({super.key, required this.controller});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late BleController _controller;

  // RC Control holding states for smooth multi-touch control
  bool _isFwd = false;
  bool _isBwd = false;
  bool _isLeft = false;
  bool _isRight = false;

  // Active center view tab: "LOGS" or "SENSORS"
  String _activeTab = "LOGS";

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      // If disconnected or mode changed, reset active driving inputs
      if (!_controller.isConnected || _controller.activeMode != "RC") {
        _isFwd = false;
        _isBwd = false;
        _isLeft = false;
        _isRight = false;
      }
      setState(() {});
    }
  }

  // Combines active driving & steering directions into a single BLE packet
  void _updateRCControls() {
    String throttle = "S";
    if (_isFwd) {
      throttle = "F";
    } else if (_isBwd) {
      throttle = "B";
    }

    String steering = "S";
    if (_isLeft) {
      steering = "L";
    } else if (_isRight) {
      steering = "R";
    }

    String cmd = "S";
    if (throttle == "F") {
      if (steering == "L") {
        cmd = "FL";
      } else if (steering == "R") {
        cmd = "FR";
      } else {
        cmd = "F";
      }
    } else if (throttle == "B") {
      if (steering == "L") {
        cmd = "BL";
      } else if (steering == "R") {
        cmd = "BR";
      } else {
        cmd = "B";
      }
    } else {
      if (steering == "L") {
        cmd = "L";
      } else if (steering == "R") {
        cmd = "R";
      } else {
        cmd = "S";
      }
    }

    _controller.sendCommand(cmd);
  }

  Widget _buildStatusHeader() {
    Color statusColor = Colors.redAccent;
    String statusText = "DISCONNECTED";
    IconData statusIcon = Icons.bluetooth_disabled;

    if (_controller.isConnected) {
      statusColor = const Color(0xFF00E5FF);
      statusText = "CONNECTED";
      statusIcon = Icons.bluetooth_connected;
    } else if (_controller.isConnecting) {
      statusColor = Colors.orangeAccent;
      statusText = "CONNECTING...";
      statusIcon = Icons.bluetooth_searching;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "DEVICE STATUS",
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.orbitron(
                    color: statusColor,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _controller.isConnecting
                ? null
                : () {
                    if (_controller.isConnected) {
                      _controller.disconnect();
                    } else {
                      _controller.startScan();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _controller.isConnected
                  ? Colors.redAccent.withOpacity(0.2)
                  : const Color(0xFF00E5FF).withOpacity(0.15),
              foregroundColor: _controller.isConnected ? Colors.redAccent : const Color(0xFF00E5FF),
              side: BorderSide(
                color: _controller.isConnected
                    ? Colors.redAccent.withOpacity(0.5)
                    : const Color(0xFF00E5FF).withOpacity(0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
            ),
            child: Text(
              _controller.isConnected ? "DISCONNECT" : "CONNECT",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 11.0,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    bool isConnected = _controller.isConnected;
    String currentMode = _controller.activeMode;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              mode: "RC",
              label: "RC CAR CONTROL",
              isSelected: currentMode == "RC",
              enabled: isConnected,
            ),
          ),
          Expanded(
            child: _buildModeButton(
              mode: "LINE",
              label: "LINE TRACING",
              isSelected: currentMode == "LINE",
              enabled: isConnected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String mode,
    required String label,
    required bool isSelected,
    required bool enabled,
  }) {
    Color activeColor = mode == "LINE" ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
    return GestureDetector(
      onTap: enabled
          ? () {
              _controller.setMode(mode);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? activeColor.withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              color: isSelected
                  ? activeColor
                  : (enabled ? Colors.white60 : Colors.white24),
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "SPEED: ",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _controller.currentSpeed,
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFFB300),
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildSpeedButton("-", Icons.remove, () {
                _controller.sendCommand("-");
              }),
              const SizedBox(width: 12.0),
              _buildSpeedButton("+", Icons.add, () {
                _controller.sendCommand("+");
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(String label, IconData icon, VoidCallback onPressed) {
    bool enabled = _controller.isConnected;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 36.0,
        height: 36.0,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: enabled ? const Color(0xFFFFB300).withOpacity(0.4) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: enabled ? const Color(0xFFFFB300) : Colors.white24,
            size: 20.0,
          ),
        ),
      ),
    );
  }

  Widget _buildLeftDriveControls() {
    bool enabled = _controller.isConnected && _controller.activeMode == "RC";
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTriggerButton(
            directionKey: "F",
            icon: Icons.keyboard_arrow_up,
            label: "FORWARD",
            color: const Color(0xFF00E5FF),
            enabled: enabled,
          ),
          Container(
            height: 2,
            width: 40,
            color: Colors.white.withOpacity(0.05),
          ),
          _buildTriggerButton(
            directionKey: "B",
            icon: Icons.keyboard_arrow_down,
            label: "REVERSE",
            color: const Color(0xFF00E5FF),
            enabled: enabled,
          ),
        ],
      ),
    );
  }

  Widget _buildRightSteerControls() {
    bool enabled = _controller.isConnected && _controller.activeMode == "RC";
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTriggerButton(
            directionKey: "L",
            icon: Icons.keyboard_arrow_left,
            label: "LEFT",
            color: const Color(0xFFFFB300),
            enabled: enabled,
          ),
          Container(
            width: 2,
            height: 40,
            color: Colors.white.withOpacity(0.05),
          ),
          _buildTriggerButton(
            directionKey: "R",
            icon: Icons.keyboard_arrow_right,
            label: "RIGHT",
            color: const Color(0xFFFFB300),
            enabled: enabled,
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerButton({
    required String directionKey,
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        if (!enabled) return;
        setState(() {
          if (directionKey == "F") _isFwd = true;
          if (directionKey == "B") _isBwd = true;
          if (directionKey == "L") _isLeft = true;
          if (directionKey == "R") _isRight = true;
        });
        _updateRCControls();
      },
      onTapUp: (_) {
        if (!enabled) return;
        setState(() {
          if (directionKey == "F") _isFwd = false;
          if (directionKey == "B") _isBwd = false;
          if (directionKey == "L") _isLeft = false;
          if (directionKey == "R") _isRight = false;
        });
        _updateRCControls();
      },
      onTapCancel: () {
        if (!enabled) return;
        setState(() {
          if (directionKey == "F") _isFwd = false;
          if (directionKey == "B") _isBwd = false;
          if (directionKey == "L") _isLeft = false;
          if (directionKey == "R") _isRight = false;
        });
        _updateRCControls();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.05) : Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: enabled ? color.withOpacity(0.4) : Colors.white.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.03),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            icon,
            color: enabled ? color : Colors.white12,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton("LOGS", "CONSOLE LOGS")),
          Expanded(child: _buildTabButton("SENSORS", "SENSOR DATA")),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    bool isSelected = _activeTab == tabKey;
    Color activeColor = tabKey == "SENSORS" ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? activeColor.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              color: isSelected ? activeColor : Colors.white38,
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorPanel() {
    final states = _controller.sensorsState;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "REAL-TIME SENSOR DATA",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSensorPod("OL", "OUTER L", states[0]),
              _buildSensorPod("IL", "INNER L", states[1]),
              _buildSensorPod("MID", "CENTER", states[2]),
              _buildSensorPod("IR", "INNER R", states[3]),
              _buildSensorPod("OR", "OUTER R", states[4]),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSensorPod(String abbrev, String label, bool isOn) {
    Color glowColor = isOn ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.05);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? glowColor.withOpacity(0.1) : Colors.white.withOpacity(0.01),
            border: Border.all(
              color: isOn ? glowColor.withOpacity(0.7) : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              abbrev,
              style: GoogleFonts.orbitron(
                color: isOn ? glowColor : Colors.white24,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isOn ? Colors.white70 : Colors.white38,
            fontSize: 8.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1.0),
        Text(
          isOn ? "BLACK" : "WHITE",
          style: GoogleFonts.orbitron(
            color: isOn ? const Color(0xFFFFB300) : Colors.white10,
            fontSize: 7.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildConsolePanel() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CONSOLE LOGS",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.consoleLogs.clear();
                  });
                },
                child: Text(
                  "CLEAR",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Expanded(
            child: _controller.consoleLogs.isEmpty
                ? Center(
                    child: Text(
                      "No communication logs yet.",
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 12.0,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _controller.consoleLogs.length,
                    itemBuilder: (context, index) {
                      final log = _controller.consoleLogs[index];
                      Color logColor = Colors.white70;
                      if (log.contains("App -> Pico")) {
                        logColor = const Color(0xFF00E5FF);
                      } else if (log.contains("Pico -> App")) {
                        logColor = const Color(0xFFFFB300);
                      } else if (log.contains("Error")) {
                        logColor = Colors.redAccent;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.0),
                        child: Text(
                          log,
                          style: GoogleFonts.firaCode(
                            color: logColor,
                            fontSize: 10.0,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        toolbarHeight: 36.0,
        title: Text(
          "PICO MOTOR CONTROL",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.0,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_controller.isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 16.0,
                  height: 16.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left control panel (Forward/Backward)
              Center(
                child: _buildLeftDriveControls(),
              ),
              const SizedBox(width: 16.0),
              // Center panel (Status, Mode selector, Speed panel, Tabs, Log/Sensor View)
              Expanded(
                child: Column(
                  children: [
                    _buildStatusHeader(),
                    _buildModeSelector(),
                    _buildSpeedPanel(),
                    _buildTabSelector(),
                    Expanded(
                      child: _activeTab == "LOGS"
                          ? _buildConsolePanel()
                          : _buildSensorPanel(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              // Right control panel (Left/Right)
              Center(
                child: _buildRightSteerControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
