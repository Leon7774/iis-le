/**
 * Simple 3-Sensor Line Follower for Arduino Nano
 * 
 * Sensor Connections:
 * - A2: Left Sensor
 * - A1: Middle Sensor
 * - A0: Right Sensor
 * 
 * Motor Connections:
 * - ENA: Pin 5 (Left Motor Speed)
 * - IN1: Pin 6 (Left Motor Dir 1)
 * - IN2: Pin 7 (Left Motor Dir 2)
 * - IN3: Pin 8 (Right Motor Dir 1)
 * - IN4: Pin 9 (Right Motor Dir 2)
 * - ENB: Pin 10 (Right Motor Speed)
 */

// Motor Pins
const int PIN_MOTOR_ENA = 5;
const int PIN_MOTOR_IN1 = 6;
const int PIN_MOTOR_IN2 = 7;
const int PIN_MOTOR_IN3 = 8;
const int PIN_MOTOR_IN4 = 9;
const int PIN_MOTOR_ENB = 10;

// Sensor Pins (A0-A2)
const int PIN_SENS_LEFT = A2;  // Left sensor
const int PIN_SENS_MID  = A1;  // Middle sensor
const int PIN_SENS_RIGHT = A0; // Right sensor

// Speed Settings (PWM values: 0 to 255)
const int BASE_SPEED  = 150;   // Normal speed on straight line
const int TURN_SPEED  = 180;   // Speed during sharp turns

// Sensor Threshold
const int THRESHOLD = 600;     // > 600 is Black line, < 600 is White background

void set_motor_velocities(int left_speed, int right_speed) {
  // Left Motor Direction
  digitalWrite(PIN_MOTOR_IN1, left_speed >= 0 ? LOW : HIGH);
  digitalWrite(PIN_MOTOR_IN2, left_speed >= 0 ? HIGH : LOW);

  // Right Motor Direction
  digitalWrite(PIN_MOTOR_IN3, right_speed >= 0 ? LOW : HIGH);
  digitalWrite(PIN_MOTOR_IN4, right_speed >= 0 ? HIGH : LOW);

  // Speed Control (PWM)
  analogWrite(PIN_MOTOR_ENA, constrain(abs(left_speed), 0, 255));
  analogWrite(PIN_MOTOR_ENB, constrain(abs(right_speed), 0, 255));
}

void setup() {
  // Initialize Serial Monitor for debugging
  Serial.begin(115200);
  Serial.println("Simple 3-Sensor Line Follower Started.");

  // Configure Motor Pins as Outputs
  pinMode(PIN_MOTOR_ENA, OUTPUT);
  pinMode(PIN_MOTOR_IN1, OUTPUT);
  pinMode(PIN_MOTOR_IN2, OUTPUT);
  pinMode(PIN_MOTOR_IN3, OUTPUT);
  pinMode(PIN_MOTOR_IN4, OUTPUT);
  pinMode(PIN_MOTOR_ENB, OUTPUT);

  // Stop initially
  set_motor_velocities(0, 0);
  delay(1000); // 1-second pause
}

void loop() {
  // Read analog sensor values
  int left_val  = analogRead(PIN_SENS_LEFT);
  int mid_val   = analogRead(PIN_SENS_MID);
  int right_val = analogRead(PIN_SENS_RIGHT);

  // Convert to binary state (true if on black line)
  bool left_black  = left_val > THRESHOLD;
  bool mid_black   = mid_val > THRESHOLD;
  bool right_black = right_val > THRESHOLD;

  // Print readings for debugging
  Serial.print("L: "); Serial.print(left_val);
  Serial.print(" | M: "); Serial.print(mid_val);
  Serial.print(" | R: "); Serial.println(right_val);

  // Line Following Logic
  if (mid_black) {
    if (!left_black && !right_black) {
      // Middle only: Go straight
      set_motor_velocities(BASE_SPEED, BASE_SPEED);
    } 
    else if (left_black && !right_black) {
      // Mid and Left: Slight left correction
      set_motor_velocities(BASE_SPEED * 0.4, BASE_SPEED);
    } 
    else if (!left_black && right_black) {
      // Mid and Right: Slight right correction
      set_motor_velocities(BASE_SPEED, BASE_SPEED * 0.4);
    }
    else {
      // All black (centered on a wide line): Go straight at full speed
      set_motor_velocities(BASE_SPEED, BASE_SPEED);
    }
  } 
  else {
    // Middle sensor is on white background
    if (left_black && !right_black) {
      // Only Left: Sharp left turn to recover
      set_motor_velocities(-TURN_SPEED * 0.2, TURN_SPEED);
    } 
    else if (!left_black && right_black) {
      // Only Right: Sharp right turn to recover
      set_motor_velocities(TURN_SPEED, -TURN_SPEED * 0.2);
    } 
    else {
      // All white (lost the line): Spin to search for the line
      set_motor_velocities(TURN_SPEED, -TURN_SPEED);
    }
  }
  
  delay(10); // Short delay to prevent loop saturation
}
