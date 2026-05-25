// Motor Pins
#define ENA 5
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9
#define ENB 10

// Sensor Pins
#define L_OUT A4  
#define L_IN  A2
#define MID   A1
#define R_IN  A0
#define R_OUT A3  

// Threshold to test
#define THRESH 600

void setup() {
  Serial.begin(9600);
  
  pinMode(ENA, OUTPUT); 
  pinMode(IN1, OUTPUT); 
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); 
  pinMode(IN4, OUTPUT); 
  pinMode(ENB, OUTPUT);
  
  // Keep motors off during sensor calibration
  analogWrite(ENA, 0);
  analogWrite(ENB, 0);
  
  Serial.println("=========================================");
  Serial.println("       Arduino Sensor Debugger           ");
  Serial.println("=========================================");
  Serial.println("Place the robot on different parts of the");
  Serial.println("track to observe the analog values.");
  Serial.println("Format: [L_OUT] [L_IN] [MID] [R_IN] [R_OUT]");
  Serial.println("-----------------------------------------");
}

void loop() {
  int lo_val = analogRead(L_OUT);
  int li_val = analogRead(L_IN);
  int mid_val = analogRead(MID);
  int ri_val = analogRead(R_IN);
  int ro_val = analogRead(R_OUT);
  
  bool LO = lo_val > THRESH;
  bool LI = li_val > THRESH;
  bool M  = mid_val > THRESH;
  bool RI = ri_val > THRESH;
  bool RO = ro_val > THRESH;
  
  // Print Raw Analog Values
  Serial.print("RAW: ");
  Serial.print(lo_val); Serial.print("\t");
  Serial.print(li_val); Serial.print("\t");
  Serial.print(mid_val); Serial.print("\t");
  Serial.print(ri_val); Serial.print("\t");
  Serial.print(ro_val); Serial.print("\t| ");
  
  // Print Boolean States (B = Black, W = White)
  Serial.print("STATE: ");
  Serial.print(LO ? "B " : "W ");
  Serial.print(LI ? "B " : "W ");
  Serial.print(M  ? "B " : "W ");
  Serial.print(RI ? "B " : "W ");
  Serial.print(RO ? "B " : "W ");
  
  // Check if current state triggers a junction in standard logic
  bool isJunction = (LO && RO) || (LO && LI && RI) || (RO && RI && LI);
  int activeSensors = (LO?1:0) + (LI?1:0) + (M?1:0) + (RI?1:0) + (RO?1:0);
  
  if (isJunction) {
    Serial.print(" | [JUNCTION DETECTED (Std)]");
  }
  if (activeSensors >= 3) {
    Serial.print(" | [JUNCTION DETECTED (3+ active)]");
  }
  if (!LO && !LI && !M && !RI && !RO) {
    Serial.print(" | [ALL WHITE / LOST]");
  }
  
  Serial.println();
  delay(250); // Read 4 times a second
}
