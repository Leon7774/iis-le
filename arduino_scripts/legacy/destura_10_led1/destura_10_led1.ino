
// --- PIN DEFINITIONS ---
constexpr uint8_t ledPins[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
constexpr uint8_t numLeds = sizeof(ledPins) / sizeof(ledPins[0]);
constexpr uint8_t buttonPin = 13;
constexpr uint8_t potPin = A0;
constexpr uint8_t ldrPin = A1;

// --- CONFIGURATION CONSTANTS ---
constexpr uint16_t DARKNESS_THRESHOLD = 400;
constexpr uint8_t DEBOUNCE_DELAY = 50;

enum LightMode {
  MODE_OFF = 0,
  MODE_CHASER,
  MODE_BOUNCE,
  MODE_FILL,
  MODE_SPLIT,
  MODE_SPARKLE,
  MODE_ALTERNATING,
  TOTAL_MODES
};

// --- STATE VARIABLES ---
unsigned long previousMillis = 0;
uint8_t currentStep = 0;
LightMode currentMode = MODE_OFF;
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
  bool isDark = (ldrValue < DARKNESS_THRESHOLD);

  bool currentButtonState = digitalRead(buttonPin);

  // Detect exact moment of button press
  if (currentButtonState == LOW && lastButtonState == HIGH) {
    currentMode = static_cast<LightMode>((currentMode + 1) % TOTAL_MODES);
    currentStep = 0;
    bounceDirection = 1;
    clearAllLeds();
    delay(DEBOUNCE_DELAY); // The sinful blocking delay
  }
  lastButtonState = currentButtonState;

  // ---------------------------------------------------------
  // 2. EXECUTE PATTERNS (Non-Blocking)
  // ---------------------------------------------------------
  unsigned long currentMillis = millis();

  if (isDark) {
    if (currentMillis - previousMillis >= speedDelay) {
      previousMillis = currentMillis;

      switch (currentMode) {
        case MODE_OFF:
          clearAllLeds();
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
        case MODE_SPLIT:
          patternSplit();
          break;
        case MODE_SPARKLE:
          patternSparkle();
          break;
        case MODE_ALTERNATING:
          patternAlternating();
          break;
      }
    }
  } else {
    clearAllLeds();
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

// --- NEW PATTERNS BELOW ---

void patternSplit() {
  clearAllLeds();
  uint8_t mid = numLeds / 2; // Finds the center point

  // Light up symmetric pairs expanding outward from the middle
  if (mid - 1 - currentStep >= 0) {
    digitalWrite(ledPins[mid - 1 - currentStep], HIGH);
  }
  if (mid + currentStep < numLeds) {
    digitalWrite(ledPins[mid + currentStep], HIGH);
  }

  currentStep++;

  // Reset when we hit the outer edges
  if (currentStep >= mid) {
    currentStep = 0;
  }
}

void patternSparkle() {
  clearAllLeds();

  // Pick a random LED index and fire it
  uint8_t randomLed = random(0, numLeds);
  digitalWrite(ledPins[randomLed], HIGH);

  // currentStep isn't doing any math here, but it's good practice
  // to tick it up just in case you modify this later to count flashes
  currentStep++;
}

void patternAlternating() {
  clearAllLeds();

  for (uint8_t i = 0; i < numLeds; i++) {
    // If currentStep is 0, light evens. If 1, light odds.
    if (i % 2 == currentStep) {
      digitalWrite(ledPins[i], HIGH);
    }
  }

  // Flip-flop between 0 and 1
  currentStep = (currentStep + 1) % 2;
}
