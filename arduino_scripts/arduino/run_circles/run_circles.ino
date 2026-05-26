// Motor Pins
#define ENA 5
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9
#define ENB 10

// Speeds for circling (adjust these to change the circle radius/direction)
#define LEFT_SPEED 150
#define RIGHT_SPEED -150

// Drive function matching original motor control logic
void drive(int l, int r) {
  digitalWrite(IN1, l >= 0 ? LOW : HIGH); 
  digitalWrite(IN2, l >= 0 ? HIGH : LOW);
  digitalWrite(IN3, r >= 0 ? LOW : HIGH); 
  digitalWrite(IN4, r >= 0 ? HIGH : LOW);
  analogWrite(ENA, constrain(abs(l), 0, 255)); 
  analogWrite(ENB, constrain(abs(r), 0, 255));
}

void setup() {
  pinMode(ENA, OUTPUT); 
  pinMode(IN1, OUTPUT); 
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); 
  pinMode(IN4, OUTPUT); 
  pinMode(ENB, OUTPUT);
}

void loop() {
  // Drive left wheel faster than right wheel to turn in a continuous circle
  drive(LEFT_SPEED, RIGHT_SPEED);
}
