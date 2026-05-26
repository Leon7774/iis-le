// ====================================
// LINE FOLLOWER — 3 SENSOR (theo_ver_2)
// ====================================

// MOTOR PINS
#define ENA 5
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9
#define ENB 10

// SENSOR PINS
#define LEFT_SENSOR  A2
#define MID_SENSOR   A1
#define RIGHT_SENSOR A0

// SETTINGS
#define BASE_SPEED 150
#define TURN_SPEED 150
#define THRESHOLD  600

// WHITE NODE / GAP CROSSING TIMEOUT (ms)
#define WHITE_NODE_TIMEOUT_MS 300 

// SURVEILLANCE
int surveillanceDirection = 1;
unsigned long lastBlackTime = 0; // Timestamp of the last time we saw the line

void setup() {
  Serial.begin(9600);
  pinMode(ENA, OUTPUT);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  pinMode(ENB, OUTPUT);
}

void driveMotors(int leftSpeed, int rightSpeed) {
  digitalWrite(IN1, leftSpeed  >= 0 ? LOW  : HIGH);
  digitalWrite(IN2, leftSpeed  >= 0 ? HIGH : LOW);
  digitalWrite(IN3, rightSpeed >= 0 ? LOW  : HIGH);
  digitalWrite(IN4, rightSpeed >= 0 ? HIGH : LOW);
  analogWrite(ENA, constrain(abs(leftSpeed),  0, 255));
  analogWrite(ENB, constrain(abs(rightSpeed), 0, 255));
}

// ====================================
// MOVEMENT METHODS
// ====================================

void goStraight() { driveMotors(BASE_SPEED, BASE_SPEED); }
void turnLeft()   { driveMotors(0, TURN_SPEED); }  // Pivot turn left (stop inner wheel instead of reversing)
void turnRight()  { driveMotors(TURN_SPEED, 0); }  // Pivot turn right (stop inner wheel instead of reversing)
void stopMotors() { driveMotors(0, 0); }

void surveil() {
  // Pivot in the last known direction (no reversing)
  if (surveillanceDirection == 1) {
    driveMotors(TURN_SPEED, 0);
  } else {
    driveMotors(0, TURN_SPEED);
  }
}

// ====================================
// MAIN LOOP
// ====================================

void loop() {
  bool L = analogRead(LEFT_SENSOR)  > THRESHOLD;
  bool M = analogRead(MID_SENSOR)   > THRESHOLD;
  bool R = analogRead(RIGHT_SENSOR) > THRESHOLD;

  // If we see the line on any sensor, update our last line detection timestamp
  if (L || M || R) {
    lastBlackTime = millis();
  }

  // Junction / wide stripe — all 3 on
  if (L && M && R) {
    goStraight();
  }

  // Veering left — correct right
  else if (L && M && !R) {
    surveillanceDirection = -1;
    turnLeft();
  }

  // Veering right — correct left
  else if (!L && M && R) {
    surveillanceDirection = 1;
    turnRight();
  }

  // Centred
  else if (!L && M && !R) {
    goStraight();
  }

  // Hard left
  else if (L && !M && !R) {
    surveillanceDirection = -1;
    turnLeft();
  }

  // Hard right
  else if (!L && !M && R) {
    surveillanceDirection = 1;
    turnRight();
  }

  // All white (gap in the line, or lost)
  else {
    // If we only recently lost the line, assume we are crossing a white node/gap and keep going straight
    if (millis() - lastBlackTime < WHITE_NODE_TIMEOUT_MS) {
      goStraight();
    } 
    // Otherwise, we are actually lost, so pivot in the last known direction to find the line
    else {
      surveil();
    }
  }

  delay(10);
}