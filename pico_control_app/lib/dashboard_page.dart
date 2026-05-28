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

  // Active center view tab: "MAP", "LOGS" or "SENSORS"
  String _activeTab = "MAP";

  // Navigation variables
  int _startNode = 1;
  int _endNode = 4;
  String _selectedAlg = "BFS";
  bool _isNavigating = false;
  bool _reachedDialogShown = false;
  String? _lastMode;

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
      if (!_controller.isConnected || _controller.activeMode != "NAV") {
        _isNavigating = false;
      }

      // Check if target node is reached and show dialog
      if (_controller.isConnected &&
          _controller.activeMode == "NAV" &&
          _controller.passedNodes.isNotEmpty &&
          _controller.passedNodes.last == _controller.navEnd &&
          !_reachedDialogShown) {
        _reachedDialogShown = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showReachedDialog();
          }
        });
      }

      // Auto-switch tabs based on active mode changes
      final mode = _controller.activeMode;
      if (mode != _lastMode) {
        if (mode == "NAV") {
          _activeTab = "MAP";
        } else if (mode == "LINE") {
          _activeTab = "SENSORS";
        }
        _lastMode = mode;
      }

      setState(() {});
    }
  }

  void _showReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 28),
              const SizedBox(width: 12.0),
              Text(
                "DESTINATION REACHED",
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          content: Text(
            "The robot has successfully navigated to Node ${_controller.navEnd} via ${_selectedAlg}.",
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "DISMISS",
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.0,
                ),
              ),
            ),
          ],
        );
      },
    );
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

  static const Map<int, List<int>> adjMap = {
    1: [0, 0, 2, 0, 7, 0, 0, 0],
    2: [0, 0, 0, 0, 4, 0, 1, 0],
    3: [0, 0, 0, 6, 0, 5, 0, 0],
    4: [2, 0, 5, 0, 9, 0, 0, 0],
    5: [0, 3, 0, 10, 0, 0, 4, 0],
    6: [0, 0, 0, 0, 0, 10, 0, 3],
    7: [1, 0, 8, 0, 0, 0, 0, 0],
    8: [0, 0, 9, 0, 11, 0, 7, 0],
    9: [4, 0, 0, 0, 0, 0, 8, 0],
    10: [0, 6, 0, 0, 12, 0, 0, 5],
    11: [8, 0, 12, 0, 13, 0, 0, 0],
    12: [10, 0, 0, 0, 14, 0, 11, 0],
    13: [11, 0, 14, 0, 18, 0, 0, 0],
    14: [12, 0, 0, 0, 16, 0, 13, 0],
    15: [0, 0, 16, 0, 19, 0, 0, 0],
    16: [14, 0, 17, 0, 0, 0, 15, 0],
    17: [0, 0, 0, 0, 21, 0, 16, 0],
    18: [13, 0, 19, 0, 0, 0, 0, 0],
    19: [15, 0, 0, 0, 20, 0, 18, 0],
    20: [19, 0, 21, 0, 0, 0, 0, 0],
    21: [17, 0, 0, 0, 0, 0, 20, 0],
  };

  // Calculates BFS Path locally for immediate UI preview
  List<int> _calculateBfsPath(int start, int goal) {
    if (start == goal) return [start];
    final Map<int, int> parentMap = {};
    final List<int> queue = [start];
    final Set<int> visited = {start};

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final neighbors = adjMap[curr] ?? [];
      for (var neighbor in neighbors) {
        if (neighbor != 0 && !visited.contains(neighbor)) {
          visited.add(neighbor);
          parentMap[neighbor] = curr;
          if (neighbor == goal) {
            final List<int> path = [];
            var node = goal;
            while (node != start) {
              path.add(node);
              node = parentMap[node]!;
            }
            path.add(start);
            return path.reversed.toList();
          }
          queue.add(neighbor);
        }
      }
    }
    return [];
  }

  // Calculates DFS Path locally for immediate UI preview
  List<int> _calculateDfsPath(int start, int goal) {
    final Set<int> visited = {};
    final List<int> path = [];
    bool dfs(int current) {
      visited.add(current);
      path.add(current);
      if (current == goal) {
        return true;
      }
      final neighbors = adjMap[current] ?? [];
      for (var neighbor in neighbors) {
        if (neighbor != 0 && !visited.contains(neighbor)) {
          if (dfs(neighbor)) {
            return true;
          }
        }
      }
      path.removeLast();
      return false;
    }
    if (dfs(start)) {
      return path;
    }
    return [];
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
              label: "RC CAR",
              isSelected: currentMode == "RC",
              enabled: isConnected,
            ),
          ),
          Expanded(
            child: _buildModeButton(
              mode: "LINE",
              label: "LINE FOLLOW",
              isSelected: currentMode == "LINE",
              enabled: isConnected,
            ),
          ),
          Expanded(
            child: _buildModeButton(
              mode: "NAV",
              label: "BFS NAV",
              isSelected: currentMode == "NAV",
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
    Color activeColor = mode == "LINE" ? const Color(0xFFFFB300) : (mode == "NAV" ? const Color(0xFF9D4EDD) : const Color(0xFF00E5FF));
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
              fontSize: 10.0,
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
    bool isLineMode = _controller.activeMode == "LINE";
    bool isNavMode = _controller.activeMode == "NAV";
    bool isConnected = _controller.isConnected;

    if (isLineMode || (isNavMode && _isNavigating)) {
      bool isPaused = _controller.isLinePaused;
      Color activeColor = isPaused ? const Color(0xFFFFB300) : Colors.redAccent;
      IconData icon = isPaused ? Icons.play_arrow : Icons.pause;
      String text = isPaused ? "RESUME" : "PAUSE";

      return GestureDetector(
        onTap: isConnected ? () => _controller.togglePause() : null,
        child: Container(
          width: 180,
          height: 152,
          decoration: BoxDecoration(
            color: isConnected ? activeColor.withOpacity(0.05) : Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(
              color: isConnected ? activeColor.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.05),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: activeColor, size: 48),
              const SizedBox(height: 8.0),
              Text(
                text,
                style: GoogleFonts.orbitron(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isNavMode && !_isNavigating) {
      Color activeColor = const Color(0xFF9D4EDD);
      return GestureDetector(
        onTap: isConnected
            ? () {
                setState(() {
                  _isNavigating = true;
                  _reachedDialogShown = false;
                  _activeTab = "MAP";
                });
                _controller.startNav(_startNode, _endNode, _selectedAlg);
              }
            : null,
        child: Container(
          width: 180,
          height: 152,
          decoration: BoxDecoration(
            color: isConnected ? activeColor.withOpacity(0.05) : Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(
              color: isConnected ? activeColor.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.05),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation, color: activeColor, size: 48),
              const SizedBox(height: 8.0),
              Text(
                "START NAV",
                style: GoogleFonts.orbitron(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

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

  Widget _buildAlgSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ROUTING MODE",
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2.0),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedAlg,
              items: ["BFS", "DFS"]
                  .map((e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedAlg = val;
                  });
                }
              },
              dropdownColor: const Color(0xFF1E1E24),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPathFinderPanel() {
    final path = _selectedAlg == "BFS" 
        ? _calculateBfsPath(_startNode, _endNode)
        : _calculateDfsPath(_startNode, _endNode);
    final pathText = path.isEmpty ? "No path found" : path.join(" ➔ ");

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNodeDropdown("START NODE", _startNode, (val) {
                if (val != null) {
                  setState(() {
                    _startNode = val;
                  });
                }
              }),
              _buildAlgSelector(),
              _buildNodeDropdown("GOAL NODE", _endNode, (val) {
                if (val != null) {
                  setState(() {
                    _endNode = val;
                  });
                }
              }),
            ],
          ),
          const SizedBox(height: 6.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "PATH PREVIEW: ",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    pathText,
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF9D4EDD),
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNodeDropdown(String label, int currentValue, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2.0),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentValue,
              items: List.generate(21, (i) => i + 1)
                  .map((e) => DropdownMenuItem<int>(
                        value: e,
                        child: Text(
                          "Node $e",
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
              dropdownColor: const Color(0xFF1E1E24),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ),
          ),
        ),
      ],
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
          Expanded(child: _buildTabButton("MAP", "TRACK MAP")),
          Expanded(child: _buildTabButton("LOGS", "CONSOLE LOGS")),
          Expanded(child: _buildTabButton("SENSORS", "SENSOR DATA")),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    bool isSelected = _activeTab == tabKey;
    Color activeColor = tabKey == "SENSORS"
        ? const Color(0xFFFFB300)
        : (tabKey == "MAP" ? const Color(0xFF9D4EDD) : const Color(0xFF00E5FF));
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
                    if (_controller.activeMode == "NAV" || _activeTab == "MAP") _buildPathFinderPanel(),
                    _buildTabSelector(),
                    Expanded(
                      child: _activeTab == "MAP"
                          ? _buildMapPanel()
                          : (_activeTab == "LOGS"
                              ? _buildConsolePanel()
                              : _buildSensorPanel()),
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

  Widget _buildMapPanel() {
    final plannedPath = _selectedAlg == "BFS" 
        ? _calculateBfsPath(_startNode, _endNode)
        : _calculateDfsPath(_startNode, _endNode);

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
        children: [
          Text(
            "INTERACTIVE TRACK MAP",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ClipRect(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(80.0),
                minScale: 0.4,
                maxScale: 3.0,
                child: CustomPaint(
                  size: const Size(900, 1350),
                  painter: NodeMapPainter(
                    startNode: _startNode,
                    goalNode: _endNode,
                    plannedPath: plannedPath,
                    passedNodes: _controller.passedNodes,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NodeMapPainter extends CustomPainter {
  final int startNode;
  final int goalNode;
  final List<int> plannedPath;
  final List<int> passedNodes;

  NodeMapPainter({
    required this.startNode,
    required this.goalNode,
    required this.plannedPath,
    required this.passedNodes,
  });

  static const Map<int, Offset> nodePositions = {
    1: Offset(0.06, 0.04),
    2: Offset(0.41, 0.04),
    3: Offset(0.76, 0.04),
    4: Offset(0.41, 0.18),
    5: Offset(0.59, 0.18),
    6: Offset(0.94, 0.18),
    7: Offset(0.06, 0.29),
    8: Offset(0.24, 0.29),
    9: Offset(0.41, 0.29),
    10: Offset(0.76, 0.32),
    11: Offset(0.24, 0.43),
    12: Offset(0.76, 0.43),
    13: Offset(0.24, 0.61),
    14: Offset(0.76, 0.61),
    15: Offset(0.59, 0.71),
    16: Offset(0.76, 0.71),
    17: Offset(0.94, 0.71),
    18: Offset(0.24, 0.86),
    19: Offset(0.59, 0.86),
    20: Offset(0.59, 0.96),
    21: Offset(0.94, 0.96),
  };

  static const Map<int, List<int>> adjMap = {
    1: [0, 0, 2, 0, 7, 0, 0, 0],
    2: [0, 0, 0, 0, 4, 0, 1, 0],
    3: [0, 0, 0, 6, 0, 5, 0, 0],
    4: [2, 0, 5, 0, 9, 0, 0, 0],
    5: [0, 3, 0, 10, 0, 0, 4, 0],
    6: [0, 0, 0, 0, 0, 10, 0, 3],
    7: [1, 0, 8, 0, 0, 0, 0, 0],
    8: [0, 0, 9, 0, 11, 0, 7, 0],
    9: [4, 0, 0, 0, 0, 0, 8, 0],
    10: [0, 6, 0, 0, 12, 0, 0, 5],
    11: [8, 0, 12, 0, 13, 0, 0, 0],
    12: [10, 0, 0, 0, 14, 0, 11, 0],
    13: [11, 0, 14, 0, 18, 0, 0, 0],
    14: [12, 0, 0, 0, 16, 0, 13, 0],
    15: [0, 0, 16, 0, 19, 0, 0, 0],
    16: [14, 0, 17, 0, 0, 0, 15, 0],
    17: [0, 0, 0, 0, 21, 0, 16, 0],
    18: [13, 0, 19, 0, 0, 0, 0, 0],
    19: [15, 0, 0, 0, 20, 0, 18, 0],
    20: [19, 0, 21, 0, 0, 0, 0, 0],
    21: [17, 0, 0, 0, 0, 0, 20, 0],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final plannedPathPaint = Paint()
      ..color = const Color(0xFF9D4EDD).withOpacity(0.55)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final traversedPathPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.6)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset getPos(int id) {
      final norm = nodePositions[id] ?? Offset.zero;
      return Offset(norm.dx * size.width, norm.dy * size.height);
    }

    // 1. Draw edges
    final Set<String> drawnEdges = {};
    adjMap.forEach((fromNode, neighbors) {
      final p1 = getPos(fromNode);
      for (var neighbor in neighbors) {
        if (neighbor != 0) {
          final edgeKey = fromNode < neighbor ? "$fromNode-$neighbor" : "$neighbor-$fromNode";
          if (!drawnEdges.contains(edgeKey)) {
            drawnEdges.add(edgeKey);
            final p2 = getPos(neighbor);
            canvas.drawLine(p1, p2, edgePaint);
          }
        }
      }
    });

    // 2. Draw planned path
    if (plannedPath.length > 1) {
      final path = Path();
      path.moveTo(getPos(plannedPath.first).dx, getPos(plannedPath.first).dy);
      for (int i = 1; i < plannedPath.length; i++) {
        final p = getPos(plannedPath[i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, plannedPathPaint);
    }

    // 3. Draw traversed path
    if (passedNodes.length > 1) {
      final path = Path();
      path.moveTo(getPos(passedNodes.first).dx, getPos(passedNodes.first).dy);
      for (int i = 1; i < passedNodes.length; i++) {
        final p = getPos(passedNodes[i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, traversedPathPaint);
    }

    // 4. Draw nodes
    const double nodeRadius = 20.0;
    final int currentRobotNode = passedNodes.isNotEmpty ? passedNodes.last : -1;

    nodePositions.forEach((id, norm) {
      final center = getPos(id);

      Color fillColor = Colors.black.withOpacity(0.8);
      Color borderColor = Colors.white30;
      double currentRadius = nodeRadius;

      if (id == currentRobotNode) {
        final pulsePaint = Paint()
          ..color = const Color(0xFF00FF88).withOpacity(0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, nodeRadius * 2.2, pulsePaint);

        final glowPaint = Paint()
          ..color = const Color(0xFF00FF88).withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, nodeRadius * 1.6, glowPaint);

        fillColor = const Color(0xFF00FF88);
        borderColor = Colors.white;
      } else if (passedNodes.contains(id)) {
        fillColor = const Color(0xFF00FF88).withOpacity(0.2);
        borderColor = const Color(0xFF00FF88);
      } else if (id == startNode) {
        fillColor = const Color(0xFF00E5FF).withOpacity(0.25);
        borderColor = const Color(0xFF00E5FF);
      } else if (id == goalNode) {
        fillColor = const Color(0xFFFF3366).withOpacity(0.25);
        borderColor = const Color(0xFFFF3366);
      } else if (plannedPath.contains(id)) {
        fillColor = const Color(0xFF9D4EDD).withOpacity(0.25);
        borderColor = const Color(0xFF9D4EDD);
      }

      canvas.drawCircle(
        center,
        currentRadius,
        Paint()..color = fillColor..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        center,
        currentRadius,
        Paint()
          ..color = borderColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );

      final textStyle = TextStyle(
        color: (id == currentRobotNode) ? Colors.black : Colors.white.withOpacity(0.9),
        fontSize: 13.0,
        fontWeight: FontWeight.bold,
        fontFamily: 'Orbitron',
      );
      final textSpan = TextSpan(
        text: "$id",
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
      );
    });
  }

  @override
  bool shouldRepaint(covariant NodeMapPainter oldDelegate) {
    return oldDelegate.startNode != startNode ||
        oldDelegate.goalNode != goalNode ||
        oldDelegate.plannedPath != plannedPath ||
        oldDelegate.passedNodes != passedNodes;
  }
}
