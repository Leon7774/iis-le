# ============================================================
# Raspberry Pi Pico W - Bluetooth & Line Tracing Control
# Supporting Manual RC, Auto Line Follow, & Weighted Node Nav
# ============================================================

import bluetooth
import math
import struct
import time
from machine import Pin, PWM, ADC

# ============================================================
# MOTOR PINS (from taraktarak_nodes.py)
# ============================================================

PWM_FREQ = 1000

ena = PWM(Pin(10))
ena.freq(PWM_FREQ)

in1 = Pin(11, Pin.OUT)
in2 = Pin(12, Pin.OUT)

enb = PWM(Pin(15))
enb.freq(PWM_FREQ)

in3 = Pin(13, Pin.OUT)
in4 = Pin(14, Pin.OUT)

# ============================================================
# SENSOR PINS & THRESHOLDS (from taraktarak_nodes.py)
# ============================================================

# OUTER DIGITAL SENSORS
outer_left  = Pin(9, Pin.IN)
outer_right = Pin(8, Pin.IN)

# CENTER ANALOG SENSORS
left_sensor   = ADC(Pin(26))
middle_sensor = ADC(Pin(27))
right_sensor  = ADC(Pin(28))

ANALOG_THRESHOLD = 60000
DIGITAL_BLACK    = 0
NAV_NODE_CENTER_MS = 180
TARGET_BRAKE_MS = 150

# ============================================================
# GRAPH DEFINITIONS
# ============================================================

DIR_NAMES = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

adj = [
    [0, 0, 0, 0, 0, 0, 0, 0], # Node 0 (Dummy)
    [0, 0, 2, 0, 7, 0, 0, 0], # Node 1
    [0, 0, 0, 0, 4, 0, 1, 0], # Node 2 (Corrected West: 1)
    [0, 0, 0, 6, 0, 5, 0, 0], # Node 3
    [2, 0, 5, 0, 9, 0, 0, 0], # Node 4
    [0, 3, 0, 10, 0, 0, 4, 0],# Node 5
    [0, 0, 0, 0, 0, 10, 0, 3],# Node 6
    [1, 0, 8, 0, 0, 0, 0, 0], # Node 7
    [0, 0, 9, 0, 11, 0, 7, 0],# Node 8
    [4, 0, 0, 0, 0, 0, 8, 0], # Node 9
    [0, 6, 0, 0, 12, 0, 0, 5],# Node 10
    [8, 0, 12, 0, 13, 0, 0, 0],# Node 11
    [10, 0, 0, 0, 14, 0, 11, 0],# Node 12
    [11, 0, 14, 0, 18, 0, 0, 0],# Node 13
    [12, 0, 0, 0, 16, 0, 13, 0],# Node 14
    [0, 0, 16, 0, 19, 0, 0, 0],# Node 15
    [14, 0, 17, 0, 0, 0, 15, 0],# Node 16
    [0, 0, 0, 0, 21, 0, 16, 0],# Node 17
    [13, 0, 19, 0, 0, 0, 0, 0],# Node 18
    [15, 0, 0, 0, 20, 0, 18, 0],# Node 19
    [19, 0, 21, 0, 0, 0, 0, 0],# Node 20
    [17, 0, 0, 0, 0, 0, 20, 0] # Node 21
]

# ============================================================
# STATE VARIABLES & SPEED SETTINGS
# ============================================================

current_speed = 80
turn_speed = 85
current_mode = "RC"       # Modes: "RC", "LINE", or "NAV"
line_paused = False       # Pauses movement in LINE/NAV modes
last_sensor_send = 0      # Telemetry timer

nav_start = 1             # Start node for pathfinder
nav_end = 4               # Goal node for pathfinder
nav_triggered = False     # Triggers path navigation sequence
nav_path_type = "SHORTEST" # Routing algorithm: "SHORTEST", "BFS", or "DFS"
last_node_time = 0        # Debounce timestamp for node detection

# ============================================================
# PATHFINDING
# ============================================================

NODE_POSITIONS = {
    1: (54, 54),
    2: (369, 54),
    3: (684, 54),
    4: (369, 243),
    5: (531, 243),
    6: (846, 243),
    7: (54, 392),
    8: (216, 392),
    9: (369, 392),
    10: (684, 432),
    11: (216, 580),
    12: (684, 580),
    13: (216, 824),
    14: (684, 824),
    15: (531, 958),
    16: (684, 958),
    17: (846, 958),
    18: (216, 1161),
    19: (531, 1161),
    20: (531, 1296),
    21: (846, 1296),
}

def edge_weight(from_node, to_node):
    x1, y1 = NODE_POSITIONS[from_node]
    x2, y2 = NODE_POSITIONS[to_node]
    dx = x1 - x2
    dy = y1 - y2
    return int(math.sqrt((dx * dx) + (dy * dy)) + 0.5)

def shortest_path(start, goal):
    if start == goal:
        return []

    dist = {}
    prev = {}
    unvisited = []
    for node in range(1, len(adj)):
        dist[node] = 999999
        unvisited.append(node)
    dist[start] = 0

    while unvisited:
        curr = None
        best = 999999
        for node in unvisited:
            if dist[node] < best:
                best = dist[node]
                curr = node

        if curr is None or curr == goal or best == 999999:
            break
        unvisited.remove(curr)

        for direction, neighbor in enumerate(adj[curr]):
            if neighbor != 0 and neighbor in unvisited:
                alt = best + edge_weight(curr, neighbor)
                if alt < dist[neighbor]:
                    dist[neighbor] = alt
                    prev[neighbor] = (curr, direction)

    if goal not in prev:
        return None

    path = []
    node = goal
    while node != start:
        parent, direction = prev[node]
        path.append((parent, direction, node))
        node = parent
    path.reverse()
    return path

def bfs_path(start, goal):
    if start == goal:
        return []

    visited = {start: None}
    queue = [start]

    while queue:
        curr = queue.pop(0)
        for direction, neighbor in enumerate(adj[curr]):
            if neighbor != 0 and neighbor not in visited:
                visited[neighbor] = (curr, direction)
                if neighbor == goal:
                    path = []
                    node = goal
                    while visited[node] is not None:
                        prev, d = visited[node]
                        path.append((prev, d, node))
                        node = prev
                    path.reverse()
                    return path
                queue.append(neighbor)
    return None

def dfs_path(start, goal):
    if start == goal:
        return []

    visited = set()
    path = []

    def dfs(curr):
        visited.add(curr)
        if curr == goal:
            return True

        for direction, neighbor in enumerate(adj[curr]):
            if neighbor != 0 and neighbor not in visited:
                path.append((curr, direction, neighbor))
                if dfs(neighbor):
                    return True
                path.pop()
        return False

    if dfs(start):
        return path
    return None

# ============================================================
# MOTOR CONTROL FUNCTIONS
# ============================================================

def drive(speed_a, speed_b, fwd_a=True, fwd_b=True):
    in1.value(1 if fwd_a else 0)
    in2.value(0 if fwd_a else 1)

    in3.value(1 if fwd_b else 0)
    in4.value(0 if fwd_b else 1)

    ena.duty_u16(int((speed_a / 100) * 65535))
    enb.duty_u16(int((speed_b / 100) * 65535))

def stop():
    drive(0, 0)

def brake(duration_ms=TARGET_BRAKE_MS):
    in1.value(1)
    in2.value(1)
    in3.value(1)
    in4.value(1)
    ena.duty_u16(65535)
    enb.duty_u16(65535)

    for _ in range(duration_ms // 10):
        if should_abort():
            break
        time.sleep_ms(10)
    stop()

# ============================================================
# SENSOR READING & NODE DETECTION
# ============================================================

def read_sensors():
    return (
        outer_left.value() != DIGITAL_BLACK,
        left_sensor.read_u16() > ANALOG_THRESHOLD,
        middle_sensor.read_u16() > ANALOG_THRESHOLD,
        right_sensor.read_u16() > ANALOG_THRESHOLD,
        outer_right.value() != DIGITAL_BLACK
    )

def is_node(s):
    # Node detected when ALL 5 sensors see black (no IR reflecting)
    return s[0] and s[1] and s[2] and s[3] and s[4]

# ============================================================
# TELEMETRY LOGGING OVER BLE
# ============================================================

def send_ble_log(msg):
    print(msg)
    global conn_handle
    if conn_handle is not None:
        try:
            ble.gatts_notify(conn_handle, tx_handle, f"{msg}\n".encode())
        except Exception as e:
            print("Failed to notify log:", e)

def send_sensors_if_time(s):
    global last_sensor_send, conn_handle
    if conn_handle is not None:
        now = time.ticks_ms()
        if time.ticks_diff(now, last_sensor_send) > 60:
            sens_str = ",".join(["1" if x else "0" for x in s])
            try:
                ble.gatts_notify(conn_handle, tx_handle, f"SENS:{sens_str}\n".encode())
            except:
                pass
            last_sensor_send = now

# ============================================================
# GRACEFUL ABORT AND NAVIGATION STEPS
# ============================================================

def should_abort():
    return current_mode not in ("LINE", "NAV")

def check_pause():
    while line_paused and not should_abort():
        stop()
        s = read_sensors()
        send_sensors_if_time(s)
        time.sleep_ms(20)

def turn_to(current_heading, target_dir):
    global turn_speed
    if current_heading == target_dir:
        send_ble_log("Already aligned.")
        return target_dir

    # Calculate shortest turn in 8-direction system
    rotation_delta = (target_dir - current_heading + 8) % 8
    if rotation_delta == 0:
        return target_dir

    direction_coefficient = -1 if rotation_delta > 4 else 1

    send_ble_log(f"TURN: {DIR_NAMES[current_heading]} -> {DIR_NAMES[target_dir]} (rot: {rotation_delta}, dir_coeff: {direction_coefficient})")

    # Use independent turn speed
    turn = turn_speed
    if direction_coefficient > 0:
        # RIGHT TURN
        drive(turn, turn, False, True)
    else:
        # LEFT TURN
        drive(turn, turn, True, False)

    # Move off current line (300ms in 10ms intervals to remain responsive to aborts/pauses)
    send_ble_log("Executing blind rotation to clear current node...")
    for _ in range(30):
        check_pause()
        if should_abort():
            stop()
            return current_heading
        
        s = read_sensors()
        send_sensors_if_time(s)
        time.sleep_ms(10)

    send_ble_log("Blind rotation done. Scanning for line...")
    # Find new line
    while not should_abort():
        check_pause()
        if should_abort():
            break
        s = read_sensors()
        send_sensors_if_time(s)
        m = s[2] # Middle sensor
        if m:
            break
        time.sleep_ms(5)

    stop()
    send_ble_log("Line aligned. Rotation complete.")
    return target_dir

def travel_to_next_node():
    global last_node_time
    last_line_time = time.ticks_ms()
    send_ble_log(f"Starting leg travel (Debounce active: last_node_time={last_node_time})")
    
    last_ignore_log = 0

    while not should_abort():
        check_pause()
        if should_abort():
            return False

        s = read_sensors()
        send_sensors_if_time(s)

        if is_node(s):
            now = time.ticks_ms()
            diff = time.ticks_diff(now, last_node_time)
            if diff > 600:
                last_node_time = now
                if current_mode == "LINE":
                    send_ble_log("Node reached! Centering over node...")
                    
                    # Move forward slightly for 80ms to center wheels over the node
                    base = current_speed
                    drive(base, base, True, True)
                    for _ in range(8):
                        check_pause()
                        if should_abort():
                            stop()
                            return False
                        
                        s_mid = read_sensors()
                        send_sensors_if_time(s_mid)
                        time.sleep_ms(10)
                    
                    send_ble_log("Turning right...")
                    # Start turning right
                    rotate_speed = min(100, current_speed + 15)
                    drive(rotate_speed, rotate_speed, False, True)
                    
                    # Move off the node square (300ms in 10ms intervals)
                    for _ in range(30):
                        check_pause()
                        if should_abort():
                            stop()
                            return False
                        
                        s_rot = read_sensors()
                        send_sensors_if_time(s_rot)
                        time.sleep_ms(10)
                    
                    # Find the new line
                    while not should_abort():
                        check_pause()
                        if should_abort():
                            break
                        s_new = read_sensors()
                        send_sensors_if_time(s_new)
                        m = s_new[2]
                        if m:
                            break
                        time.sleep_ms(5)
                        
                    stop()
                    send_ble_log("Found new line! Resuming follow...")
                    last_line_time = time.ticks_ms()
                    continue
                else:
                    # NAV mode: first detection is the leading edge of the node.
                    # Move forward briefly so the robot is centered before turn_to().
                    send_ble_log("Node edge detected. Centering over node before turn...")
                    drive(current_speed, current_speed, True, True)
                    for _ in range(NAV_NODE_CENTER_MS // 10):
                        check_pause()
                        if should_abort():
                            stop()
                            return False
                        s_mid = read_sensors()
                        send_sensors_if_time(s_mid)
                        time.sleep_ms(10)
                    stop()
                    send_ble_log(f"Node reached successfully! (diff: {diff}ms)")
                    return True
            else:
                if time.ticks_diff(now, last_ignore_log) > 200:
                    last_ignore_log = now
                    print(f"[NAV DEBUG] Node detected but ignored (debounce diff: {diff}ms <= 600ms)")

        left_black = s[1]
        middle_black = s[2]
        right_black = s[3]

        # Dynamic speeds based on app settings (current_speed)
        base = current_speed
        rotate_speed = min(100, current_speed + 15)

        # Update last seen line time if any center sensor sees black
        if left_black or middle_black or right_black:
            last_line_time = time.ticks_ms()

        # Line Tracing Logic from taraktarak.py
        if left_black and middle_black and right_black:
            drive(base, base, True, True)       # Drive Forward
        elif left_black:
            drive(rotate_speed, rotate_speed, True, False)  # Rotate Left
        elif right_black:
            drive(rotate_speed, rotate_speed, False, True)  # Rotate Right
        elif middle_black:
            drive(base, base, True, True)       # Drive Forward
        else:
            # Only stop if we have been on white for more than 300ms
            if time.ticks_diff(time.ticks_ms(), last_line_time) > 300:
                stop()                              # No line, stop
            else:
                pass                                # Coast/keep last action

        time.sleep_ms(10)
    return False

def run_navigation_sequence(start_node, end_node, path_type):
    global last_node_time
    last_node_time = time.ticks_ms()
    
    send_ble_log(f"Calculating path Node {start_node} -> Node {end_node} via {path_type}...")
    if path_type == "DFS":
        path = dfs_path(start_node, end_node)
    elif path_type == "BFS":
        path = bfs_path(start_node, end_node)
    else:
        path = shortest_path(start_node, end_node)
        
    if not path:
        send_ble_log("Error: No path found!")
        return False

    send_ble_log(f"Path found: {path}")
    
    # --- CHANGED LOGIC HERE ---
    # Instead of hardcoding East (2), we assume the user placed the robot
    # facing the correct direction for the first step based on our app UI.
    # path[0] looks like (from_node, direction, to_node)
    curr_h = path[0][1] 
    send_ble_log(f"Initial physical placement assumed to be: {DIR_NAMES[curr_h]}")
    # --------------------------

    for idx, step in enumerate(path):
        if should_abort():
            send_ble_log("Navigation aborted by user.")
            return False

        from_n, direction, to_n = step
        send_ble_log(f"Leg [{idx + 1}/{len(path)}]: Node {from_n} -> Node {to_n} ({DIR_NAMES[direction]})")

        curr_h = turn_to(curr_h, direction)
        if should_abort():
            send_ble_log("Navigation aborted by user during turn.")
            return False

        # Reset the debounce timestamp AFTER the turn is completed.
        last_node_time = time.ticks_ms()
        send_ble_log(f"Turn done. Debounce reset to {last_node_time}. Moving to next node...")

        if not travel_to_next_node():
            send_ble_log("Travel failed or lost line.")
            return False
        
        curr_h = direction
        
        # Notify the app that we reached the node
        global conn_handle
        if conn_handle is not None:
            try:
                ble.gatts_notify(conn_handle, tx_handle, f"REACHED:{to_n}\n".encode())
                send_ble_log(f"App notified: REACHED Node {to_n}")
            except Exception as e:
                print("Failed to notify reached node:", e)

    send_ble_log("Target node reached. Braking...")
    brake()
    send_ble_log(f"SUCCESS: Arrived at Destination Node {end_node}!")
    return True

# ============================================================
# COMMAND HANDLER
# ============================================================

def handle_command(cmd):
    global current_speed, current_mode, line_paused, nav_start, nav_end, nav_triggered, nav_path_type, turn_speed
    cmd = cmd.strip().upper()
    print("CMD:", cmd)

    if cmd == "M:RC":
        current_mode = "RC"
        line_paused = False
        nav_triggered = False
        stop()
        send_ble_log("Mode switched: RC Control")
    elif cmd == "M:LINE":
        current_mode = "LINE"
        line_paused = False
        nav_triggered = False
        send_ble_log("Mode switched: Line Tracing")
    elif cmd == "M:NAV":
        current_mode = "NAV"
        line_paused = False
        nav_triggered = False
        stop()
        send_ble_log("Mode switched: Weighted Nav (Standby)")
    elif cmd == "M:PAUSE":
        line_paused = True
        stop()
        send_ble_log("Line Tracing Paused")
    elif cmd.startswith("T:"):
        try:
            turn_speed = int(cmd.split(":")[1])
            send_ble_log(f"Turn speed set to {turn_speed}%")
        except Exception as e:
            print("Error parsing Turn Speed:", e)
    elif cmd.startswith("NAV:"):
        try:
            parts = cmd.split(":")
            nodes = parts[1].split(",")
            nav_start = int(nodes[0])
            nav_end = int(nodes[1])
            nav_path_type = "SHORTEST"
            if len(nodes) > 2:
                nav_path_type = nodes[2].strip().upper()
            current_mode = "NAV"
            line_paused = False
            nav_triggered = True
            send_ble_log(f"Nav Triggered ({nav_path_type}): {nav_start} -> {nav_end}")
        except Exception as e:
            print("Error parsing NAV command:", e)
    elif current_mode == "RC":
        # RC Car Mode Drive Controls
        if cmd == "F":
            drive(current_speed, current_speed, True, True)
        elif cmd == "B":
            drive(current_speed, current_speed, False, False)
        elif cmd == "L":
            drive(current_speed, current_speed, True, False)
        elif cmd == "R":
            drive(current_speed, current_speed, False, True)
        elif cmd == "FL":
            drive(int(current_speed * 0.45), current_speed, True, True)
        elif cmd == "FR":
            drive(current_speed, int(current_speed * 0.45), True, True)
        elif cmd == "BL":
            drive(int(current_speed * 0.45), current_speed, False, False)
        elif cmd == "BR":
            drive(current_speed, int(current_speed * 0.45), False, False)
        elif cmd == "S":
            stop()
    
    # Speed adjustment (available in all modes)
    if cmd == "+":
        current_speed = min(100, current_speed + 10)
        print(f"Speed: {current_speed}%")
    elif cmd == "-":
        current_speed = max(10, current_speed - 10)
        print(f"Speed: {current_speed}%")

# ============================================================
# BLE SETUP (Nordic UART Service)
# ============================================================

UART_SERVICE = bluetooth.UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
UART_RX      = bluetooth.UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
UART_TX      = bluetooth.UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

_FLAG_WRITE         = const(0x0008)
_FLAG_NOTIFY        = const(0x0010)
_FLAG_WRITE_NO_RESP = const(0x0004)

ble = bluetooth.BLE()
ble.active(True)

# Register services
((tx_handle, rx_handle),) = ble.gatts_register_services([
    (UART_SERVICE, [
        (UART_TX, _FLAG_NOTIFY,),
        (UART_RX, _FLAG_WRITE | _FLAG_WRITE_NO_RESP,),
    ]),
])

conn_handle = None

# ============================================================
# BLE ADVERTISE
# ============================================================

def advertise():
    name = b"PicoMotor"
    adv = bytearray([
        0x02, 0x01, 0x06,
        len(name) + 1, 0x09,
    ]) + name
    ble.gap_advertise(100000, adv_data=adv)
    print("Advertising as 'PicoMotor'...")

# ============================================================
# BLE EVENT HANDLER
# ============================================================

def ble_irq(event, data):
    global conn_handle, current_speed, current_mode, line_paused, turn_speed

    if event == 1:  # Connected
        conn_handle = data[0]
        print("Phone connected!")
        ble.gap_advertise(None)  # stop advertising

    elif event == 2:  # Disconnected
        conn_handle = None
        current_mode = "RC"
        line_paused = False
        stop()
        print("Phone disconnected — re-advertising...")
        advertise()

    elif event == 3:  # Write received
        buf = ble.gatts_read(rx_handle)
        if buf:
            try:
                handle_command(buf.decode("utf-8"))
            except Exception as e:
                print("Error handling command:", e)
            
            # Notify back the current speed, mode, and pause status
            if conn_handle is not None:
                reply_spd = f"SPD:{current_speed}%\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_spd)
                reply_mode = f"MODE:{current_mode}\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_mode)
                reply_pause = f"PAUSE:{1 if line_paused else 0}\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_pause)
                reply_turn = f"TSPD:{turn_speed}%\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_turn)

ble.irq(ble_irq)

# ============================================================
# MAIN LOOP
# ============================================================

advertise()

try:
    last_mode = "RC"
    while True:
        # Send real-time sensor updates to client every 60ms if connected in RC mode
        if conn_handle is not None and current_mode == "RC":
            s = read_sensors()
            send_sensors_if_time(s)

        if current_mode == "LINE":
            if last_mode == "RC":
                last_mode = "LINE"
                send_ble_log("Starting Line Tracing (Right Turn on Nodes)...")
                travel_to_next_node()
                # Automatically fall back to RC mode when finished or aborted
                current_mode = "RC"
                last_mode = "RC"
                # Update client UI with the mode reversion
                if conn_handle is not None:
                    ble.gatts_notify(conn_handle, tx_handle, b"MODE:RC\n")
                    ble.gatts_notify(conn_handle, tx_handle, b"PAUSE:0\n")
        elif current_mode == "NAV":
            if last_mode != "NAV":
                last_mode = "NAV"
            if nav_triggered:
                run_navigation_sequence(nav_start, nav_end, nav_path_type)
                nav_triggered = False
                current_mode = "RC"
                last_mode = "RC"
                if conn_handle is not None:
                    ble.gatts_notify(conn_handle, tx_handle, b"MODE:RC\n")
                    ble.gatts_notify(conn_handle, tx_handle, b"PAUSE:0\n")
        else:
            last_mode = "RC"
            time.sleep_ms(50)
except KeyboardInterrupt:
    print("Stopping...")
    stop()
    ble.active(False)
