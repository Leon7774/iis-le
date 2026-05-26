// =========================================================
// INDUSTRY STANDARD: State Machines using Enums
// Instead of using arbitrary "magic numbers" (0, 1, 2) to 
// track patterns, use an enumeration. It makes the code 
// self-documenting, easier to read, and prevents you from 
// accidentally assigning a state that doesn't exist.
// =========================================================

// --- PIN DEFINITIONS ---
// constexpr uint8_t ledPins[] = {8, 2, 9, 3, 10, 4, 11, 5, 12, 6};
constexpr uint8_t ledPins[] = {2, 3, 4, 5, 6, 7, 8, 9, 10,11};
constexpr uint8_t numLeds = sizeof(ledPins) / sizeof(ledPins[0]);
constexpr uint8_t buttonPin = 13; 
constexpr uint8_t potPin = A0;
constexpr uint8_t ldrPin = A1; 

// --- CONFIGURATION CONSTANTS ---
constexpr uint16_t DARKNESS_THRESHOLD = 500; 
constexpr uint8_t DEBOUNCE_DELAY = 50;

// Define our states clearly. 
// TOTAL_MODES automatically equals 4, which is a neat C++ trick.
enum LightMode {
  MODE_OFF = 0,
  MODE_CHASER,
  MODE_BOUNCE,
  MODE_FILL,
  TOTAL_MODES 
};

// --- STATE VARIABLES ---
unsigned long previousMillis = 0; 
uint8_t currentStep = 0;          
LightMode currentMode = MODE_OFF; // Plug in -> NO LIGHT (Start here)
bool lastButtonState = HIGH;      
int8_t bounceDirection = 1;       

void setup() {
  Serial.begin(115200); 
  
  for (uint8_t i = 0; i < numLeds; i++) {
    pinMode(ledPins[i], OUTPUT);
  }
  pinMode(buttonPin, INPUT_PULLUP); 
  pinMode(ldrPin, INPUT);
}

void loop() {
  // ---------------------------------------------------------
  // 1. READ INPUTS
  // ---------------------------------------------------------
  uint16_t potValue = analogRead(potPin);
  uint16_t speedDelay = map(potValue, 0, 1023, 20, 400); 

  uint16_t ldrValue = analogRead(ldrPin);
  bool isDark = (ldrValue > DARKNESS_THRESHOLD);

  bool currentButtonState = digitalRead(buttonPin);
  
  // Detect exact moment of button press
  if (currentButtonState == LOW && lastButtonState == HIGH) {
    
    // Cycle to the next mode, and wrap around to 0 (OFF) when we hit the max
    currentMode = static_cast<LightMode>((currentMode + 1) % TOTAL_MODES);
    
    currentStep = 0; 
    bounceDirection = 1;
    clearAllLeds(); 
    delay(DEBOUNCE_DELAY); 
  }
  lastButtonState = currentButtonState;

  // ---------------------------------------------------------
  // 2. EXECUTE PATTERNS (Non-Blocking)
  // ---------------------------------------------------------
  unsigned long currentMillis = millis();
  
  if (currentMillis - previousMillis >= speedDelay) {
    previousMillis = currentMillis; 
    
    // Only run the logic if it is dark enough
    if (isDark) {
      switch (currentMode) {
        case MODE_OFF:
          clearAllLeds(); // Chill in the darkness
          break;
        case MODE_CHASER:
          patternChaser();
          break;
        case MODE_BOUNCE:
          patternBounce();
          break;
        case MODE_FILL:
          patternFill();
          break;
      }
    } else {
      // If the lights are on in the room, force OFF
      clearAllLeds();
    }
  }
}

// =========================================================
// HELPER FUNCTIONS & PATTERN LOGIC
// =========================================================

void clearAllLeds() {
  for (uint8_t i = 0; i < numLeds; i++) {
    digitalWrite(ledPins[i], LOW);
  }
}

void patternChaser() {
  clearAllLeds(); 
  digitalWrite(ledPins[currentStep], HIGH); 
  
  currentStep++;
  if (currentStep >= numLeds) {
    currentStep = 0; 
  }
}

void patternBounce() {
  clearAllLeds();
  digitalWrite(ledPins[currentStep], HIGH);
  
  currentStep += bounceDirection; 
  
  if (currentStep >= numLeds - 1) {
    bounceDirection = -1;
  } else if (currentStep <= 0) {
    bounceDirection = 1;
  }
}

void patternFill() {
  digitalWrite(ledPins[currentStep], HIGH); 
  
  currentStep++;
  
  if (currentStep > numLeds) {
    clearAllLeds();
    currentStep = 0;
  }
}