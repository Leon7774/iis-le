# ============================================================
# Raspberry Pi Pico W - LINE FOLLOWER
# OUTER SENSORS IGNORED VERSION
# ============================================================

from machine import Pin, PWM, ADC
import time

# ============================================================
# MOTOR DRIVER PINS (L298N)
# ============================================================

PWM_FREQ = 1000

# --- Motor A ---
ena = PWM(Pin(10))
ena.freq(PWM_FREQ)

in1 = Pin(11, Pin.OUT)
in2 = Pin(12, Pin.OUT)

# --- Motor B ---
enb = PWM(Pin(15))
enb.freq(PWM_FREQ)

in3 = Pin(13, Pin.OUT)
in4 = Pin(14, Pin.OUT)

# ============================================================
# SENSOR PINS
# ============================================================

# OUTER DIGITAL SENSORS
# (Currently unused)

outer_left  = Pin(6, Pin.IN)
outer_right = Pin(5, Pin.IN)

# CENTER ANALOG SENSORS

left_sensor   = ADC(Pin(26))
middle_sensor = ADC(Pin(27))
right_sensor  = ADC(Pin(28))

# ============================================================
# ANALOG THRESHOLD
# ============================================================

# LOWER VALUE = BLACK

THRESHOLD = 60000

# ============================================================
# MOTOR FUNCTIONS
# ============================================================

def set_speed(pwm, speed):

    speed = max(0, min(100, speed))

    duty = int((speed / 100) * 65535)

    pwm.duty_u16(duty)

def motor_a(speed, forward=True):

    in1.value(1 if forward else 0)
    in2.value(0 if forward else 1)

    set_speed(ena, speed)

def motor_b(speed, forward=True):

    in3.value(1 if forward else 0)
    in4.value(0 if forward else 1)

    set_speed(enb, speed)

# ============================================================
# MOVEMENT FUNCTIONS
# ============================================================

# FORWARD
def drive_forward():

    motor_a(65, True)
    motor_b(65, True)

# ROTATE LEFT
def rotate_right():

    # Left wheels backward
    motor_a(80, False)

    # Right wheels forward
    motor_b(80, True)

# ROTATE RIGHT
def rotate_left():

    # Left wheels forward
    motor_a(80, True)

    # Right wheels backward
    motor_b(80, False)

# STOP
def stop_all():

    motor_a(0, True)
    motor_b(0, True)

# ============================================================
# STARTUP
# ============================================================

print("===================================")
print(" LINE FOLLOWER STARTED ")
print("===================================")

time.sleep(1)

# ============================================================
# MAIN LOOP
# ============================================================

while True:

    # ========================================================
    # READ ANALOG CENTER SENSORS
    # ========================================================

    left_raw   = left_sensor.read_u16()
    middle_raw = middle_sensor.read_u16()
    right_raw  = right_sensor.read_u16()

    # ========================================================
    # BLACK DETECTION
    # ========================================================

    # BLACK = LOWER VALUE

    left_black   = left_raw   > THRESHOLD
    middle_black = middle_raw > THRESHOLD
    right_black  = right_raw  > THRESHOLD

    # ========================================================
    # DEBUG OUTPUT
    # ========================================================

    print(
        "RAW:",
        left_raw,
        middle_raw,
        right_raw,
        "|",
        [left_black, middle_black, right_black]
    )

    # ========================================================
    # LINE FOLLOWING LOGIC
    # ========================================================

    # --------------------------------------------------------
    # ALL 3 SENSORS DETECT BLACK
    # MOVE FORWARD
    # --------------------------------------------------------
    if left_black and middle_black and right_black:

        drive_forward()

    # --------------------------------------------------------
    # LEFT DETECTS BLACK
    # ROTATE LEFT
    # --------------------------------------------------------
    elif left_black:

        rotate_left()

    # --------------------------------------------------------
    # RIGHT DETECTS BLACK
    # ROTATE RIGHT
    # --------------------------------------------------------
    elif right_black:

        rotate_right()

    # --------------------------------------------------------
    # MIDDLE DETECTS BLACK
    # MOVE FORWARD
    # --------------------------------------------------------
    elif middle_black:

        drive_forward()

    # --------------------------------------------------------
    # NO BLACK DETECTED
    # --------------------------------------------------------
    else:

        stop_all()

    time.sleep(0.01)