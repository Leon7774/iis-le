/**
 * ESP32 Move Forward Code (4-Pin Motor Driver)
 * 
 * This sketch drives a two-wheeled robot forward.
 * Configured for 4-pin motor control (like DRV8833, MX1508, or L298N without speed enable pins).
 * 
 * Pin mapping:
 * - Left Motor:  GPIO 12 and GPIO 5
 * - Right Motor: GPIO 13 and GPIO 4
 */

// ==========================================
// PIN CONFIGURATION
// ==========================================
const int PIN_LEFT_A  = 12; // Left Motor Pin A
const int PIN_LEFT_B  = 5;  // Left Motor Pin B
const int PIN_RIGHT_A = 13; // Right Motor Pin A
const int PIN_RIGHT_B = 4;  // Right Motor Pin B

// Speed values range from 0 (stopped) to 255 (full speed)
const int MOVE_SPEED = 200; 

/**
 * Sets motor speeds and directions for 4-pin control.
 * Positive speed = forward, Negative speed = backward, 0 = stop.
 */
void set_motor_velocities(int left_speed, int right_speed) {
  // Left Motor Control
  if (left_speed > 0) {
    analogWrite(PIN_LEFT_A, constrain(abs(left_speed), 0, 255));
    analogWrite(PIN_LEFT_B, 0);
  } else if (left_speed < 0) {
    analogWrite(PIN_LEFT_A, 0);
    analogWrite(PIN_LEFT_B, constrain(abs(left_speed), 0, 255));
  } else {
    analogWrite(PIN_LEFT_A, 0);
    analogWrite(PIN_LEFT_B, 0);
  }

  // Right Motor Control
  if (right_speed > 0) {
    analogWrite(PIN_RIGHT_A, constrain(abs(right_speed), 0, 255));
    analogWrite(PIN_RIGHT_B, 0);
  } else if (right_speed < 0) {
    analogWrite(PIN_RIGHT_A, 0);
    analogWrite(PIN_RIGHT_B, constrain(abs(right_speed), 0, 255));
  } else {
    analogWrite(PIN_RIGHT_A, 0);
    analogWrite(PIN_RIGHT_B, 0);
  }
}

void setup() {
  // Initialize Serial Monitor
  Serial.begin(115200);
  Serial.println("ESP Motor Test: Moving Forward (4-Pin mode)...");

  // Configure pins as outputs
  pinMode(PIN_LEFT_A, OUTPUT);
  pinMode(PIN_LEFT_B, OUTPUT);
  pinMode(PIN_RIGHT_A, OUTPUT);
  pinMode(PIN_RIGHT_B, OUTPUT);

  // Stop the motors initially
  set_motor_velocities(0, 0);
  delay(1000); // Wait 1 second before starting
}

void loop() {
  // Drive forward at the configured speed
  Serial.println("Driving forward...");
  set_motor_velocities(MOVE_SPEED, MOVE_SPEED);
  
  delay(5000); // Drive forward for 5 seconds

  // Stop for 2 seconds
  Serial.println("Stopping...");
  set_motor_velocities(0, 0);
  
  delay(2000); // Wait 2 seconds before repeating
}
