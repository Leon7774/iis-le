# ============================================================
# Raspberry Pi Pico W - SIMPLIFIED NODE NAVIGATION (4 DIRECTIONS)
# ============================================================
from machine import Pin, PWM, ADC
import time
from collections import deque

# ============================================================
# MOTOR DRIVER PINS (L298N)
# ============================================================
PWM_FREQ = 1000
ena = PWM(Pin(10)); ena.freq(PWM_FREQ)
in1 = Pin(11, Pin.OUT)
in2 = Pin(12, Pin.OUT)
enb = PWM(Pin(15)); enb.freq(PWM_FREQ)
in3 = Pin(13, Pin.OUT)
in4 = Pin(14, Pin.OUT)

# ============================================================
# SENSOR PINS & THRESHOLDS
# ============================================================
outer_left  = Pin(8, Pin.IN)   # Digital
outer_right = Pin(9, Pin.IN)   # Digital
left_sensor   = ADC(Pin(26))   # Analog
middle_sensor = ADC(Pin(27))   # Analog
right_sensor  = ADC(Pin(28))   # Analog

ANALOG_THRESHOLD  = 60000 
DIGITAL_BLACK     = 0       

# ============================================================
# GRAPH (4 Directions: 0=N, 1=E, 2=S, 3=W)
# ============================================================
adj = [
    [0, 0, 0, 0], # Node 0 (Dummy)
    [0, 2, 0, 0], # Node 1: East to 2
    [0, 0, 3, 1], # Node 2: South to 3, West to 1
    [2, 0, 0, 4], # Node 3: North to 2, West to 4
    [0, 3, 0, 0]  # Node 4: East to 3
]

DIR_NAMES = ["N", "E", "S", "W"]
OPPOSITE = {0: 2, 1: 3, 2: 0, 3: 1}

# ============================================================
# NAVIGATION LOGIC (BFS)
# ============================================================
def bfs_path(start, goal):
    if start == goal: return []
    visited = {start: None}
    queue = deque([start])
    while queue:
        curr = queue.popleft()
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
# MOTOR MOVEMENT
# ============================================================
BASE_SPEED = 65
TURN_SPEED = 75

def drive(speed_a, speed_b, fwd_a=True, fwd_b=True):
    in1.value(1 if fwd_a else 0); in2.value(0 if fwd_a else 1)
    in3.value(1 if fwd_b else 0); in4.value(0 if fwd_b else 1)
    ena.duty_u16(int((speed_a/100)*65535))
    enb.duty_u16(int((speed_b/100)*65535))

def stop(): drive(0, 0)

# ============================================================
# SENSOR UTILS
# ============================================================
def read_sensors():
    return (outer_left.value() == DIGITAL_BLACK,
            left_sensor.read_u16() > ANALOG_THRESHOLD,
            middle_sensor.read_u16() > ANALOG_THRESHOLD,
            right_sensor.read_u16() > ANALOG_THRESHOLD,
            outer_right.value() == DIGITAL_BLACK)

def is_node(sensors):
    return all(sensors) # All 5 sensors on black

# ============================================================
# EXECUTION FUNCTIONS
# ============================================================
def turn_to(current_heading, target_dir):
    if current_heading == target_dir: return target_dir
    
    # Calculate shortest turn in 4-direction system
    diff = (target_dir - current_heading) % 4
    if diff == 3: diff = -1 # Turn left instead of 3x right
    
    if diff > 0: drive(TURN_SPEED, TURN_SPEED, False, True)  # Right
    else:        drive(TURN_SPEED, TURN_SPEED, True, False)  # Left

    time.sleep_ms(300) # Move off current line
    while True:
        _, _, m, _, _ = read_sensors()
        if m: break # Found new line
    stop()
    return target_dir

def travel_to_next_node():
    while True:
        s = read_sensors()
        if is_node(s):
            stop()
            return
        
        # Simple Line Follower Logic
        if s[1] and not s[3]:   drive(BASE_SPEED-20, BASE_SPEED+10) # Adjust Left
        elif s[3] and not s[1]: drive(BASE_SPEED+10, BASE_SPEED-20) # Adjust Right
        else:                   drive(BASE_SPEED, BASE_SPEED)       # Straight
        time.sleep_ms(10)

def navigate(path, start_heading):
    curr_h = start_heading
    for from_node, direction, to_node in path:
        print(f"Moving {from_node} -> {to_node} ({DIR_NAMES[direction]})")
        curr_h = turn_to(curr_h, direction)
        travel_to_next_node()
        curr_h = direction 
    print("DESTINATION REACHED")

# ============================================================
# MAIN RUNNER
# ============================================================
START_NODE = 1
END_NODE   = 4
INITIAL_HEADING = 1 # Facing East (towards node 2)

print("Pathfinding...")
full_path = bfs_path(START_NODE, END_NODE)

if full_path:
    print("Path found:", [f"{step[0]}->{step[2]}" for step in full_path])
    time.sleep(2)
    navigate(full_path, INITIAL_HEADING)
else:
    print("No path found!")