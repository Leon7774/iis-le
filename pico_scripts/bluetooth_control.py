# ============================================================
# Raspberry Pi Pico W - Bluetooth & Line Tracing Control
# Using control logic from taraktarak_nodes.py
# ============================================================

import bluetooth
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
outer_left  = Pin(8, Pin.IN)
outer_right = Pin(9, Pin.IN)

# CENTER ANALOG SENSORS
left_sensor   = ADC(Pin(26))
middle_sensor = ADC(Pin(27))
right_sensor  = ADC(Pin(28))

ANALOG_THRESHOLD = 60000
DIGITAL_BLACK    = 0

# ============================================================
# GRAPH DEFINITIONS
# ============================================================

DIR_NAMES = ["N", "E", "S", "W"]

adj = [
    [0, 0, 0, 0], # Node 0 (Dummy)
    [0, 2, 0, 0], # Node 1: East to 2
    [0, 0, 3, 1], # Node 2: South to 3, West to 1
    [2, 0, 0, 4], # Node 3: North to 2, West to 4
    [0, 3, 0, 0]  # Node 4: East to 3
]

# ============================================================
# STATE VARIABLES & SPEED SETTINGS (from taraktarak_nodes.py)
# ============================================================

current_speed = 80
current_mode = "RC"  # Modes: "RC" or "LINE"

BASE_SPEED = 65
TURN_SPEED = 75

# ============================================================
# BFS PATHFINDING
# ============================================================

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

# ============================================================
# SENSOR READING & NODE DETECTION
# ============================================================

def read_sensors():
    return (
        outer_left.value() == DIGITAL_BLACK,
        left_sensor.read_u16() > ANALOG_THRESHOLD,
        middle_sensor.read_u16() > ANALOG_THRESHOLD,
        right_sensor.read_u16() > ANALOG_THRESHOLD,
        outer_right.value() == DIGITAL_BLACK
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

# ============================================================
# GRACEFUL ABORT AND NAVIGATION STEPS (from taraktarak_nodes.py)
# ============================================================

def should_abort():
    return current_mode != "LINE"

def turn_to(current_heading, target_dir):
    if current_heading == target_dir:
        send_ble_log("Already aligned.")
        return target_dir

    # Calculate shortest turn in 4-direction system
    diff = (target_dir - current_heading) % 4
    if diff == 3:
        diff = -1

    send_ble_log(f"TURN: {DIR_NAMES[current_heading]} -> {DIR_NAMES[target_dir]}")

    if diff > 0:
        # RIGHT TURN
        drive(TURN_SPEED, TURN_SPEED, False, True)
    else:
        # LEFT TURN
        drive(TURN_SPEED, TURN_SPEED, True, False)

    # Move off current line (300ms in 10ms intervals to remain responsive to aborts)
    for _ in range(30):
        if should_abort():
            stop()
            return current_heading
        time.sleep_ms(10)

    # Find new line
    while not should_abort():
        s = read_sensors()
        m = s[2] # Middle sensor
        if m:
            break
        time.sleep_ms(5)

    stop()
    return target_dir

def travel_to_next_node():
    while not should_abort():
        s = read_sensors()
        if is_node(s):
            stop()
            send_ble_log("NODE DETECTED")
            return True

        # Simple Line Follower Logic
        if s[1] and not s[3]:
            drive(BASE_SPEED - 20, BASE_SPEED + 10) # Adjust Left
        elif s[3] and not s[1]:
            drive(BASE_SPEED + 10, BASE_SPEED - 20) # Adjust Right
        else:
            drive(BASE_SPEED, BASE_SPEED)           # Straight
        time.sleep_ms(10)
    return False

def run_navigation_sequence():
    START_NODE = 1
    END_NODE = 4
    INITIAL_HEADING = 1 # Facing East (towards node 2)
    curr_h = INITIAL_HEADING

    send_ble_log("Calculating path Node 1 -> Node 4...")
    path = bfs_path(START_NODE, END_NODE)
    if not path:
        send_ble_log("Error: No path found!")
        return False

    send_ble_log(f"Path: {path}")

    # Executes navigation loop directly
    for step in path:
        if should_abort():
            return False

        from_n, direction, to_n = step
        send_ble_log(f"Leg: Node {from_n} -> {to_n} ({DIR_NAMES[direction]})")

        curr_h = turn_to(curr_h, direction)
        if should_abort():
            return False

        if not travel_to_next_node():
            return False
        
        curr_h = direction

    stop()
    send_ble_log(f"SUCCESS: Arrived at Destination Node {END_NODE}!")
    return True

# ============================================================
# COMMAND HANDLER
# ============================================================

def handle_command(cmd):
    global current_speed, current_mode
    cmd = cmd.strip().upper()
    print("CMD:", cmd)

    if cmd == "M:RC":
        current_mode = "RC"
        stop()
        send_ble_log("Mode switched: RC Control")
    elif cmd == "M:LINE":
        current_mode = "LINE"
        send_ble_log("Mode switched: Line Tracing")
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
    
    # Speed adjustment (available in both modes)
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
    global conn_handle, current_speed, current_mode

    if event == 1:  # Connected
        conn_handle = data[0]
        print("Phone connected!")
        ble.gap_advertise(None)  # stop advertising

    elif event == 2:  # Disconnected
        conn_handle = None
        current_mode = "RC"
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
            
            # Notify back the current speed and mode status
            if conn_handle is not None:
                reply_spd = f"SPD:{current_speed}%\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_spd)
                reply_mode = f"MODE:{current_mode}\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply_mode)

ble.irq(ble_irq)

# ============================================================
# MAIN LOOP
# ============================================================

advertise()

try:
    last_mode = "RC"
    last_sensor_send = 0
    while True:
        # Send real-time sensor updates to client every 150ms if connected
        if conn_handle is not None:
            now = time.ticks_ms()
            if time.ticks_diff(now, last_sensor_send) > 150:
                s = read_sensors()
                sens_str = ",".join(["1" if x else "0" for x in s])
                try:
                    ble.gatts_notify(conn_handle, tx_handle, f"SENS:{sens_str}\n".encode())
                except:
                    pass
                last_sensor_send = now

        if current_mode == "LINE":
            if last_mode == "RC":
                last_mode = "LINE"
                # Run the navigation sequence
                run_navigation_sequence()
                # Automatically fall back to RC mode when finished or aborted
                current_mode = "RC"
                last_mode = "RC"
                # Update client UI with the mode reversion
                if conn_handle is not None:
                    ble.gatts_notify(conn_handle, tx_handle, b"MODE:RC\n")
        else:
            last_mode = "RC"
            time.sleep_ms(50)
except KeyboardInterrupt:
    print("Stopping...")
    stop()
    ble.active(False)
