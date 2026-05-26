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
      setState(() {});
    }
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
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DEVICE STATUS",
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  statusText,
                  style: GoogleFonts.orbitron(
                    color: statusColor,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
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
                borderRadius: BorderRadius.circular(16.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              elevation: 0,
            ),
            child: Text(
              _controller.isConnected ? "DISCONNECT" : "CONNECT",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13.0,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CURRENT SPEED",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                _controller.currentSpeed,
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFFB300),
                  fontSize: 32.0,
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
              const SizedBox(width: 16.0),
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
        width: 56.0,
        height: 56.0,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: enabled ? const Color(0xFFFFB300).withOpacity(0.4) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: enabled ? const Color(0xFFFFB300) : Colors.white24,
            size: 28.0,
          ),
        ),
      ),
    );
  }

  Widget _buildDpad() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.02),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 2.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Up Button
            Positioned(
              top: 10.0,
              child: _buildDpadButton(
                direction: "FORWARD",
                command: "F",
                icon: Icons.keyboard_arrow_up,
                angle: 0,
              ),
            ),
            // Down Button
            Positioned(
              bottom: 10.0,
              child: _buildDpadButton(
                direction: "REVERSE",
                command: "B",
                icon: Icons.keyboard_arrow_down,
                angle: 180,
              ),
            ),
            // Left Button
            Positioned(
              left: 10.0,
              child: _buildDpadButton(
                direction: "LEFT",
                command: "L",
                icon: Icons.keyboard_arrow_left,
                angle: 270,
              ),
            ),
            // Right Button
            Positioned(
              right: 10.0,
              child: _buildDpadButton(
                direction: "RIGHT",
                command: "R",
                icon: Icons.keyboard_arrow_right,
                angle: 90,
              ),
            ),
            // Center Stop Button
            GestureDetector(
              onTap: _controller.isConnected
                  ? () => _controller.sendCommand("S")
                  : null,
              child: Container(
                width: 72.0,
                height: 72.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _controller.isConnected
                      ? Colors.redAccent.withOpacity(0.15)
                      : Colors.white.withOpacity(0.03),
                  border: Border.all(
                    color: _controller.isConnected
                        ? Colors.redAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.1),
                    width: 2.0,
                  ),
                  boxShadow: _controller.isConnected
                      ? [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    "STOP",
                    style: GoogleFonts.orbitron(
                      color: _controller.isConnected ? Colors.redAccent : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDpadButton({
    required String direction,
    required String command,
    required IconData icon,
    required double angle,
  }) {
    bool enabled = _controller.isConnected;
    
    return GestureDetector(
      onTapDown: (_) {
        if (enabled) {
          _controller.sendCommand(command);
        }
      },
      onTapUp: (_) {
        if (enabled) {
          _controller.sendCommand("S");
        }
      },
      onTapCancel: () {
        if (enabled) {
          _controller.sendCommand("S");
        }
      },
      child: Container(
        width: 80.0,
        height: 80.0,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: enabled ? const Color(0xFF00E5FF).withOpacity(0.4) : Colors.white.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.03),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            icon,
            color: enabled ? const Color(0xFF00E5FF) : Colors.white12,
            size: 40.0,
          ),
        ),
      ),
    );
  }

  Widget _buildConsolePanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CONSOLE LOGS",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 11.0,
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
          const SizedBox(height: 10.0),
          SizedBox(
            height: 120.0,
            child: _controller.consoleLogs.isEmpty
                ? Center(
                    child: Text(
                      "No communication logs yet.",
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 13.0,
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
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log,
                          style: GoogleFonts.firaCode(
                            color: logColor,
                            fontSize: 11.0,
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
        title: Text(
          "PICO MOTOR CONTROL",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            letterSpacing: 1.5,
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
                  width: 18.0,
                  height: 18.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusHeader(),
            _buildSpeedPanel(),
            Expanded(
              child: Center(
                child: _buildDpad(),
              ),
            ),
            _buildConsolePanel(),
          ],
        ),
      ),
    );
  }
}
