
#  Raspberry Pi Pico W - Motor Control via Bluetooth LE
#  No external libraries needed — uses built-in bluetooth only
#  Motor A: ENA=GP10, IN1=GP11, IN2=GP12
#  Motor B: ENB=GP15, IN3=GP13, IN4=GP14


import bluetooth
import struct
import time
from machine import Pin, PWM

# --- Motor Setup ---
PWM_FREQ = 1000
ena = PWM(Pin(10)); ena.freq(PWM_FREQ)
enb = PWM(Pin(15)); enb.freq(PWM_FREQ)
in1 = Pin(11, Pin.OUT)
in2 = Pin(12, Pin.OUT)
in3 = Pin(13, Pin.OUT)
in4 = Pin(14, Pin.OUT)

current_speed = 80

# ============================================================
#  Motor Functions
# ============================================================

def set_speed(pwm, speed):
    pwm.duty_u16(int((speed / 100) * 65535))

def motor_a(speed, forward=True):
    in1.value(1 if forward else 0)
    in2.value(0 if forward else 1)
    set_speed(ena, speed)

def motor_b(speed, forward=True):
    in3.value(1 if forward else 0)
    in4.value(0 if forward else 1)
    set_speed(enb, speed)

def stop_all():
    set_speed(ena, 0); set_speed(enb, 0)
    in1.value(0); in2.value(0)
    in3.value(0); in4.value(0)

def drive_forward(s):  motor_a(s, True);  motor_b(s, True)
def drive_reverse(s):  motor_a(s, False); motor_b(s, False)
def turn_left(s):      motor_a(s, False); motor_b(s, True)
def turn_right(s):     motor_a(s, True);  motor_b(s, False)

def handle_command(cmd):
    global current_speed
    cmd = cmd.strip().upper()
    print("CMD:", cmd)
    if   cmd == "F": drive_forward(current_speed)
    elif cmd == "B": drive_reverse(current_speed)
    elif cmd == "L": turn_left(current_speed)
    elif cmd == "R": turn_right(current_speed)
    elif cmd == "S": stop_all()
    elif cmd == "+": current_speed = min(100, current_speed + 10); print(f"Speed: {current_speed}%")
    elif cmd == "-": current_speed = max(10,  current_speed - 10); print(f"Speed: {current_speed}%")

# ============================================================
#  BLE Setup (Nordic UART Service)
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
#  BLE Advertise
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
#  BLE Event Handler
# ============================================================

def ble_irq(event, data):
    global conn_handle, current_speed

    if event == 1:  # Connected
        conn_handle = data[0]
        print("Phone connected!")
        ble.gap_advertise(None)  # stop advertising

    elif event == 2:  # Disconnected
        conn_handle = None
        stop_all()
        print("Phone disconnected — re-advertising...")
        advertise()

    elif event == 3:  # Write received
        buf = ble.gatts_read(rx_handle)
        if buf:
            handle_command(buf.decode("utf-8"))
            # Notify back
            if conn_handle is not None:
                reply = f"SPD:{current_speed}%\n".encode()
                ble.gatts_notify(conn_handle, tx_handle, reply)

ble.irq(ble_irq)

# ==============