#include <avr/pgmspace.h>

// PINS
#define ENA 5
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9
#define ENB 10

#define L_OUT A4  
#define L_IN  A2
#define MID   A1
#define R_IN  A0
#define R_OUT A3  

// SETTINGS (Restored from v1)
#define THRESH 600  // Standard: Black is > 600, White is < 600
#define SPD 110    
#define T_SPD 180  
#define LOOP_PENALTY 150 
#define MIN_NODE_TIME 1000 // Minimum ms between nodes to prevent double-counting

// MAP DATA
#define MAX_NODES 50
const int8_t NODE_XY[MAX_NODES][2] PROGMEM = {{0,0}, {7,5}, {18,5}, {27,5}, {47,4}, {42,9}, {52,9}, {7,18}, {18,18}, {27,18}, {38,14}, {47,14}, {57,14}, {42,19}, {52,19}, {7,30}, {18,30}, {27,30}, {47,30}, {24,38}, {47,38}, {10,41}, {57,41}, {18,44}, {36,44}, {47,44}, {10,49}, {57,49}, {24,52}, {47,52}, {18,59}, {39,59}, {47,59}, {57,59}, {7,63}, {18,63}, {30,63}, {39,63}, {47,63}, {57,63}, {30,66}, {39,66}, {47,66}, {57,66}};
const int GRAPH[MAX_NODES][8] PROGMEM = {{0,0,0,0,0,0,0,0}, {0,0,2,0,7,0,0,0}, {0,0,3,0,8,0,1,0}, {0,0,0,0,9,0,2,0}, {0,0,0,6,0,5,0,0}, {0,4,0,11,0,10,0,0}, {0,0,0,12,0,11,0,4}, {1,0,8,0,15,0,0,0}, {2,0,9,0,16,0,7,0}, {3,0,10,0,17,0,8,0}, {0,5,0,13,0,0,9,0}, {0,6,0,14,0,13,0,5}, {0,0,0,0,0,14,0,6}, {0,11,0,18,0,0,0,10}, {0,12,0,0,0,18,0,11}, {7,0,16,0,0,0,0,0}, {8,0,17,0,19,0,15,0}, {9,0,0,0,0,0,16,0}, {0,14,0,0,20,0,0,13}, {16,0,20,0,23,0,21,0}, {18,0,22,0,25,0,19,0}, {0,19,0,26,0,0,0,0}, {0,0,0,0,0,27,0,20}, {19,0,24,0,28,0,0,0}, {0,0,25,0,0,0,23,0}, {20,0,0,0,29,0,24,0}, {0,0,0,28,0,0,0,21}, {0,22,0,0,0,29,0,0}, {23,0,29,0,30,0,26,0}, {25,0,27,0,32,0,28,0}, {28,0,36,0,35,0,34,0}, {0,0,32,0,37,0,0,0}, {29,0,33,0,38,0,31,0}, {0,0,0,0,39,0,32,0}, {30,0,35,0,40,0,0,0}, {30,0,36,0,40,0,34,0}, {30,0,37,0,40,0,35,0}, {31,0,38,0,41,0,36,0}, {32,0,39,0,42,0,37,0}, {33,0,0,0,43,0,38,0}, {35,0,36,0,0,0,34,0}, {37,0,42,0,0,0,0,0}, {38,0,43,0,0,0,41,0}, {39,0,0,0,0,0,42,0}};

// CONFIGURATION
#define START_NODE 17
#define END_NODE 23
#define INITIAL_HEADING 6

// STATE
int8_t curN = START_NODE;
int8_t prevN = -1;
int8_t faceD = INITIAL_HEADING;
unsigned long lastNodeTime = 0;
int junctionDebounce = 0; // Counter to validate junction
int whiteDebounce = 0;    // Counter to validate white marker
bool foundFirstLine = false;

// PATHFINDING STATE
int8_t path[MAX_NODES];
uint8_t pathLength = 0;
uint8_t pathIndex = 0;

void drive(int l, int r) {
  digitalWrite(IN1, l >= 0 ? LOW : HIGH); digitalWrite(IN2, l >= 0 ? HIGH : LOW);
  digitalWrite(IN3, r >= 0 ? LOW : HIGH); digitalWrite(IN4, r >= 0 ? HIGH : LOW);
  analogWrite(ENA, constrain(abs(l), 0, 255)); analogWrite(ENB, constrain(abs(r), 0, 255));
}

// Find shortest path using BFS on the graph
bool findShortestPath(int8_t start, int8_t end) {
  int8_t parent[MAX_NODES];
  int8_t queue[MAX_NODES];
  
  for (int i = 0; i < MAX_NODES; i++) {
    parent[i] = -1;
  }
  
  int head = 0;
  int tail = 0;
  
  queue[tail++] = start;
  parent[start] = start; // Start node points to itself
  
  while (head < tail) {
    int8_t curr = queue[head++];
    if (curr == end) {
      break;
    }
    
    for (int d = 0; d < 8; d++) {
      int neighbor = (int)pgm_read_word(&GRAPH[curr][d]);
      if (neighbor > 0 && parent[neighbor] == -1) {
        parent[neighbor] = curr;
        queue[tail++] = (int8_t)neighbor;
      }
    }
  }
  
  if (parent[end] == -1) {
    return false; // Path not found
  }
  
  // Reconstruct path in reverse
  int8_t curr = end;
  int8_t tempPath[MAX_NODES];
  uint8_t count = 0;
  
  while (curr != start) {
    tempPath[count++] = curr;
    curr = parent[curr];
  }
  tempPath[count++] = start;
  
  // Store path in correct forward order
  pathLength = count;
  for (uint8_t i = 0; i < count; i++) {
    path[i] = tempPath[count - 1 - i];
  }
  
  return true;
}

void handleJunction(bool isWhiteMarker) {
  if (isWhiteMarker) {
    // 1. Arrived at next node on the path
    pathIndex++;
    curN = path[pathIndex];

    // 2. Check if we reached the final destination node
    if (curN == END_NODE || pathIndex >= pathLength - 1) {
      drive(0, 0); // Stop motors
      while(1);    // Halt
    }

    // 3. Find target direction to the next node in the path
    int8_t nextN = path[pathIndex + 1];
    int targetD = -1;
    for (int d = 0; d < 8; d++) {
      int nb = (int)pgm_read_word(&GRAPH[curN][d]);
      if (nb == nextN) {
        targetD = d;
        break;
      }
    }

    // Navigation error fallback (indicates node connection is missing in GRAPH)
    if (targetD == -1) {
      drive(0, 0);
      pinMode(13, OUTPUT);
      while (1) {
        digitalWrite(13, HIGH); delay(100);
        digitalWrite(13, LOW); delay(100);
      }
    }

    // 4. Update state variables without executing mechanical turn (just follow curve)
    prevN = path[pathIndex - 1];
    faceD = targetD;
    lastNodeTime = millis(); // Reset travel clock
    whiteDebounce = 0;
    junctionDebounce = 0;
    return;
  }

  // STANDARD BLACK JUNCTION
  drive(0,0); delay(300); // Stop and settle

  // 1. Arrived at next node on the path
  pathIndex++;
  curN = path[pathIndex];

  // 2. Check if we reached the final destination node
  if (curN == END_NODE || pathIndex >= pathLength - 1) {
    drive(0, 0); // Stop motors
    while(1);    // Halt
  }

  // 3. Find target direction to the next node in the path
  int8_t nextN = path[pathIndex + 1];
  int targetD = -1;
  for (int d = 0; d < 8; d++) {
    int nb = (int)pgm_read_word(&GRAPH[curN][d]);
    if (nb == nextN) {
      targetD = d;
      break;
    }
  }

  // Navigation error fallback (indicates node connection is missing in GRAPH)
  if (targetD == -1) {
    drive(0, 0);
    pinMode(13, OUTPUT);
    while (1) {
      digitalWrite(13, HIGH); delay(100);
      digitalWrite(13, LOW); delay(100);
    }
  }

  // 4. Turn to the target direction
  int diff = (targetD - faceD + 8) % 8;
  if (diff != 0) {
    int turnDir = (diff > 4) ? -1 : 1;
    drive(T_SPD * turnDir, -T_SPD * turnDir);
    delay(300); // Clear current line
    while(analogRead(MID) > THRESH); // Wait for white
    while(analogRead(MID) < THRESH); // Wait for next black line
    drive(0,0); delay(100);
  }

  // 5. Update state variables
  prevN = path[pathIndex - 1];
  faceD = targetD;
  lastNodeTime = millis(); // Reset travel clock
  junctionDebounce = 0;    // Reset debounce
  whiteDebounce = 0;
}

void setup() {
  pinMode(ENA, OUTPUT); pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT); pinMode(ENB, OUTPUT);
  
  // Calculate shortest path
  if (!findShortestPath(START_NODE, END_NODE)) {
    // Flash LED rapidly on pathfinding failure
    pinMode(13, OUTPUT);
    while (1) {
      digitalWrite(13, HIGH); delay(150);
      digitalWrite(13, LOW); delay(150);
    }
  }
  
  lastNodeTime = millis(); // Prevent false junction detection at startup
}

void loop() {
  bool LO = analogRead(L_OUT) > THRESH;
  bool LI = analogRead(L_IN)  > THRESH;
  bool M  = analogRead(MID)   > THRESH;
  bool RI = analogRead(R_IN)  > THRESH;
  bool RO = analogRead(R_OUT) > THRESH;

  if (!foundFirstLine) {
    if (LO || LI || M || RI || RO) foundFirstLine = true;
    else { drive(SPD, SPD); return; }
  }

  // Determine if the next node on our path is a white tape marker
  int8_t nextN = (pathIndex < pathLength - 1) ? path[pathIndex + 1] : -1;
  bool approachingWhiteNode = (nextN == 21 || nextN == 22 || nextN == 26 || nextN == 27);

  if (approachingWhiteNode) {
    // White Marker Detection (all sensors see white)
    bool isWhiteMarker = (!LO && !LI && !M && !RI && !RO);
    if (isWhiteMarker) {
      if (millis() - lastNodeTime > MIN_NODE_TIME) {
        whiteDebounce++;
        if (whiteDebounce > 6) { // Must see white marker for 6 loops (~60ms)
          handleJunction(true);
        }
      }
    } else {
      whiteDebounce = 0;
    }
  } else {
    whiteDebounce = 0;
  }

  // 1. JUNCTION DETECTION WITH DEBOUNCING (Restored from v1)
  // We check if the outer sensors are hitting black
  if ((LO && RO) || (LO && LI && RI) || (RO && RI && LI)) {
    if (millis() - lastNodeTime > MIN_NODE_TIME) {
      junctionDebounce++;
      if (junctionDebounce > 5) { // Must see junction for 5 loops (~50ms)
        handleJunction(false);
      }
    }
  } else {
    junctionDebounce = 0; // Reset if we see white
  }

  // 2. LINE FOLLOWING (Only if not in a junction and not on a white marker)
  if (junctionDebounce == 0 && whiteDebounce == 0) {
    if (M) {
      if (LI && !RI)      drive(SPD * 0.4, SPD); 
      else if (RI && !LI) drive(SPD, SPD * 0.4); 
      else                drive(SPD, SPD);
    } 
    else if (LI) drive(SPD * 0.2, SPD); 
    else if (RI) drive(SPD, SPD * 0.2); 
    else if (LO) drive(-T_SPD, T_SPD); 
    else if (RO) drive(T_SPD, -T_SPD); 
    else { drive(T_SPD, -T_SPD); } // Lost
  }
}
