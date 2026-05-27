# ============================================================
# Raspberry Pi Pico W - GRAPH NAVIGATION ROBOT
# NODE 1 -> NODE 4
# ============================================================

from machine import Pin, PWM, ADC
import time

# ============================================================
# MOTOR PINS
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
# SENSOR PINS
# ============================================================

# OUTER DIGITAL SENSORS
outer_left  = Pin(8, Pin.IN)
outer_right = Pin(9, Pin.IN)

# CENTER ANALOG SENSORS
left_sensor   = ADC(Pin(26))
middle_sensor = ADC(Pin(27))
right_sensor  = ADC(Pin(28))

# ============================================================
# SENSOR SETTINGS
# ============================================================

ANALOG_THRESHOLD = 60000
DIGITAL_BLACK    = 0

# ============================================================
# DIRECTION MAP
# ============================================================

# 0 = NORTH
# 1 = EAST
# 2 = SOUTH
# 3 = WEST

DIR_NAMES = [
    "NORTH",
    "EAST",
    "SOUTH",
    "WEST"
]

# ============================================================
# GRAPH
# ============================================================

adj = [

    [0, 0, 0, 0],

    [0, 2, 0, 0], # Node 1
    [0, 0, 3, 1], # Node 2
    [2, 0, 0, 4], # Node 3
    [0, 3, 0, 0]  # Node 4
]

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
# MOTOR CONTROL
# ============================================================

BASE_SPEED = 60
TURN_SPEED = 70

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
# SENSOR READING
# ============================================================

def read_sensors():

    outer_l = (outer_left.value() == DIGITAL_BLACK)

    left = left_sensor.read_u16() > ANALOG_THRESHOLD

    middle = middle_sensor.read_u16() > ANALOG_THRESHOLD

    right = right_sensor.read_u16() > ANALOG_THRESHOLD

    outer_r = (outer_right.value() == DIGITAL_BLACK)

    return (
        outer_l,
        left,
        middle,
        right,
        outer_r
    )

# ============================================================
# NODE DETECTION
# ============================================================

def is_node(s):

    # BOTH OUTERS + MIDDLE
    return s[0] and s[2] and s[4]

# ============================================================
# MOVE OFF NODE
# ============================================================

def move_off_node():

    print("Clearing node...")

    drive(BASE_SPEED, BASE_SPEED)

    time.sleep_ms(450)

    stop()

# ============================================================
# TURNING
# ============================================================

def turn_to(current_heading, target_dir):

    # ========================================================
    # ALREADY FACING TARGET
    # ========================================================

    if current_heading == target_dir:

        print("Already aligned.")

        return target_dir

    # ========================================================
    # DETERMINE ROTATION
    # ========================================================

    diff = (target_dir - current_heading) % 4

    if diff == 3:
        diff = -1

    print(
        "TURN:",
        DIR_NAMES[current_heading],
        "->",
        DIR_NAMES[target_dir]
    )

    # ========================================================
    # START ROTATION
    # ========================================================

    if diff > 0:

        # RIGHT TURN
        drive(TURN_SPEED, TURN_SPEED, False, True)

    else:

        # LEFT TURN
        drive(TURN_SPEED, TURN_SPEED, True, False)

    # ========================================================
    # LEAVE CURRENT LINE
    # ========================================================

    time.sleep_ms(250)

    # ========================================================
    # FIND NEW LINE
    # ========================================================

    while True:

        s = read_sensors()

        # MIDDLE SENSOR MUST SEE LINE
        # OUTERS MUST NOT SEE NODE

        if s[2] and not s[0] and not s[4]:

            break

    stop()

    time.sleep_ms(200)

    return target_dir

# ============================================================
# LINE FOLLOWING
# ============================================================

def travel_to_next_node():

    while True:

        s = read_sensors()

        print("SENSORS:", s)

        # ====================================================
        # NODE DETECTED
        # ====================================================

        if is_node(s):

            stop()

            print("NODE DETECTED")

            return

        # ====================================================
        # TOO FAR RIGHT
        # ====================================================

        if s[1] and not s[3]:

            drive(BASE_SPEED - 25, BASE_SPEED + 10)

        # ====================================================
        # TOO FAR LEFT
        # ====================================================

        elif s[3] and not s[1]:

            drive(BASE_SPEED + 10, BASE_SPEED - 25)

        # ====================================================
        # CENTERED
        # ====================================================

        else:

            drive(BASE_SPEED, BASE_SPEED)

        time.sleep_ms(5)

# ============================================================
# MAIN PROGRAM
# ============================================================

# IMPORTANT:
# Place robot BELOW Node 1
# facing NORTH toward Node 1

START_NODE = 1
END_NODE   = 4

# INITIAL HEADING = NORTH
CURR_HEAD = 0

# ============================================================
# COMPUTE PATH
# ============================================================

path = bfs_path(START_NODE, END_NODE)

# ============================================================
# EXECUTE PATH
# ============================================================

if path:

    print("===================================")
    print("PATH FOUND")
    print("===================================")

    print("PATH:", path)

    print("")
    print("STARTING IN 2 SECONDS...")
    print("PLACE ROBOT BELOW NODE 1")
    print("FACING NORTH")
    print("")

    time.sleep(2)

    # ========================================================
    # FIRST:
    # MOVE TO NODE 1
    # ========================================================

    print("MOVING TO NODE 1")

    travel_to_next_node()

    # ========================================================
    # NAVIGATION LOOP
    # ========================================================

    for step in path:

        from_n, direction, to_n = step

        print("")
        print("-----------------------------------")
        print("CURRENT NODE:", from_n)
        print("TARGET NODE :", to_n)
        print("TARGET DIR  :", DIR_NAMES[direction])
        print("-----------------------------------")

        # ====================================================
        # MOVE PAST CURRENT NODE
        # ====================================================

        move_off_node()

        # ====================================================
        # ROTATE TOWARD NEXT PATH
        # ====================================================

        CURR_HEAD = turn_to(
            CURR_HEAD,
            direction
        )

        # ====================================================
        # FOLLOW LINE TO NEXT NODE
        # ====================================================

        travel_to_next_node()

    # ========================================================
    # DESTINATION REACHED
    # ========================================================

    stop()

    print("")
    print("===================================")
    print(" ARRIVED AT NODE", END_NODE)
    print("===================================")

else:

    print("NO PATH FOUND")