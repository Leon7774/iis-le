// ====================================
// LINE FOLLOWER — 3 SENSOR
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
#define BASE_SPEED 180
#define TURN_SPEED 180
#define THRESHOLD  700

// SURVEILLANCE
int surveillanceDirection = 1;

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
void turnLeft()   { driveMotors(-TURN_SPEED, TURN_SPEED); }
void turnRight()  { driveMotors(TURN_SPEED, -TURN_SPEED); }
void stopMotors() { driveMotors(0, 0); }

void surveil() {
  driveMotors(surveillanceDirection * TURN_SPEED,
             -surveillanceDirection * TURN_SPEED);
}

// ====================================
// MAIN LOOP
// ====================================

void loop() {
  bool L = analogRead(LEFT_SENSOR)  > THRESHOLD;
  bool M = analogRead(MID_SENSOR)   > THRESHOLD;
  bool R = analogRead(RIGHT_SENSOR) > THRESHOLD;

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

  // Lost — spin in last known direction
  else {
    surveil();
  }

  delay(10);
}