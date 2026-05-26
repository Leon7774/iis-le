// ====================================
// LINE FOLLOWER — 3 SENSOR (theo_ver_3)
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
#define THRESHOLD  300

// WHITE NODE / GAP CROSSING TIMEOUT (ms)
#define WHITE_NODE_TIMEOUT_MS 300 

// SURVEILLANCE / SEARCH STATE
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
void steerLeft()  { driveMotors(BASE_SPEED * 0.4, BASE_SPEED); } // Smooth steer left
void steerRight() { driveMotors(BASE_SPEED, BASE_SPEED * 0.4); } // Smooth steer right
void turnLeft()   { driveMotors(0, TURN_SPEED); }                // Sharp pivot turn left
void turnRight()  { driveMotors(TURN_SPEED, 0); }                // Sharp pivot turn right
void stopMotors() { driveMotors(0, 0); }

void surveil() {
  // Rover forward in a wide sweeping curve in the last known direction (no reversing)
  if (surveillanceDirection == 1) {
    driveMotors(BASE_SPEED, BASE_SPEED * 0.3); // Sweep right
  } else {
    driveMotors(BASE_SPEED * 0.3, BASE_SPEED); // Sweep left
  }
}

// ====================================
// MAIN LOOP
// ====================================

void loop() {
  int L = analogRead(LEFT_SENSOR);
  int M = analogRead(MID_SENSOR);
  int R = analogRead(RIGHT_SENSOR);

  // Print raw values for debugging
  Serial.print("L: "); Serial.print(L);
  Serial.print(" | M: "); Serial.print(M);
  Serial.print(" | R: "); Serial.print(R);
  Serial.print(" | State: ");

  // If we see the line on any sensor, update our last line detection timestamp
  if (L > THRESHOLD || M > THRESHOLD || R > THRESHOLD) {
    lastBlackTime = millis();
  }

  // Centered on a wide line (all 3 black) or middle only
  if ((L > THRESHOLD && M > THRESHOLD && R > THRESHOLD) || 
      (L <= THRESHOLD && M > THRESHOLD && R <= THRESHOLD)) {
    Serial.println("Straight");
    goStraight();
  }

  // Veering left (line is on the left) — steer left smoothly
  else if (L > THRESHOLD && M > THRESHOLD && R <= THRESHOLD) {
    surveillanceDirection = -1;
    Serial.println("Steer Left");
    steerLeft();
  }

  // Veering right (line is on the right) — steer right smoothly
  else if (L <= THRESHOLD && M > THRESHOLD && R > THRESHOLD) {
    surveillanceDirection = 1;
    Serial.println("Steer Right");
    steerRight();
  }

  // Hard left (line is only on the left sensor) — sharp pivot left
  else if (L > THRESHOLD && M <= THRESHOLD && R <= THRESHOLD) {
    surveillanceDirection = -1;
    Serial.println("Pivot Left");
    turnLeft();
  }

  // Hard right (line is only on the right sensor) — sharp pivot right
  else if (L <= THRESHOLD && M <= THRESHOLD && R > THRESHOLD) {
    surveillanceDirection = 1;
    Serial.println("Pivot Right");
    turnRight();
  }

  // All white (gap in the line, or lost)
  else {
    // If we only recently lost the line, assume we are crossing a white node/gap and keep going straight
    if (millis() - lastBlackTime < WHITE_NODE_TIMEOUT_MS) {
      Serial.println("Gap Straight");
      goStraight();
    } 
    // Otherwise, we are actually lost, so "rover" forward in a sweeping curve to find it
    else {
      Serial.println("Surveil (Rover)");
      surveil();
    }
  }

  delay(250);
}
