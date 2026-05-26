// ====================================
// SIMPLE LINE FOLLOWER W/ SURVEILLANCE
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
#define BASE_SPEED -180
#define TURN_SPEED -180
#define THRESHOLD    600

// SURVEILLANCE
int surveillanceDirection = 1; // 1 = right, -1 = left

// ====================================
// SETUP
// ====================================

void setup() {
  Serial.begin(9600);

  pinMode(ENA, OUTPUT); pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT); pinMode(ENB, OUTPUT);
}

// ====================================
// MOTOR DRIVER
// ====================================

void driveMotors(int leftSpeed, int rightSpeed) {
  digitalWrite(IN1, leftSpeed  >= 0 ? LOW : HIGH);
  digitalWrite(IN2, leftSpeed  >= 0 ? HIGH : LOW);
  digitalWrite(IN3, rightSpeed >= 0 ? LOW : HIGH);
  digitalWrite(IN4, rightSpeed >= 0 ? HIGH : LOW);

  analogWrite(ENA, constrain(abs(leftSpeed),  0, 255));
  analogWrite(ENB, constrain(abs(rightSpeed), 0, 255));
}

// ====================================
// DIRECTION METHODS
// ====================================

void goStraight() {
  driveMotors(BASE_SPEED, BASE_SPEED);
}

void turnRight() {
  driveMotors(-TURN_SPEED, TURN_SPEED);
}

void turnLeft() {
  driveMotors(TURN_SPEED, -TURN_SPEED);
}

void surveil() {
  int speed = TURN_SPEED / 2;
  driveMotors(surveillanceDirection * speed, -surveillanceDirection * speed);
}

// ====================================
// MAIN LOOP
// ====================================

void loop() {
  int rawL = analogRead(LEFT_SENSOR);
  int rawM = analogRead(MID_SENSOR);
  int rawR = analogRead(RIGHT_SENSOR);

  Serial.print("L: "); Serial.print(rawL);
  Serial.print("  M: "); Serial.print(rawM);
  Serial.print("  R: "); Serial.println(rawR);

  // All white — lost the line entirely
  if (rawL < THRESHOLD && rawM < THRESHOLD && rawR < THRESHOLD) {
    surveil();

  // All three on line — centered on a wide line or intersection, go straight
  } else if (rawL > THRESHOLD && rawM > THRESHOLD && rawR > THRESHOLD) {
    goStraight();

  // Left + Mid on line, Right off — veer left
  } else if (rawL > THRESHOLD && rawM > THRESHOLD && rawR < THRESHOLD) {
    surveillanceDirection = -1;
    turnLeft();

  // Mid + Right on line, Left off — veer right
  } else if (rawL < THRESHOLD && rawM > THRESHOLD && rawR > THRESHOLD) {
    surveillanceDirection =  1;
    turnRight();

  // Only Mid on line — centered, go straight
  } else if (rawL < THRESHOLD && rawM > THRESHOLD && rawR < THRESHOLD) {
    goStraight();

  // Only Left on line, Mid + Right off — hard left
  } else if (rawL > THRESHOLD && rawM < THRESHOLD && rawR < THRESHOLD) {
    surveillanceDirection = -1;
    turnLeft();

  // Only Right on line, Mid + Left off — hard right
  } else if (rawL < THRESHOLD && rawM < THRESHOLD && rawR > THRESHOLD) {
    surveillanceDirection =  1;
    turnRight();
  }

  delay(10);
}