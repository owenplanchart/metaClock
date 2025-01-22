import processing.serial.*;
import processing.sound.*;

Serial myPort;  // Serial port for Arduino
int cx, cy;
float secondsRadius;
PFont f;
float baseSecond = 0;  // Tracks the current second with speed adjustments
float speedMultiplier = 1;  // Speed factor from the distance sensor
int lastTime;  // Tracks the time of the previous frame
int lastSecond = 0; // Tracks the last integer second for sound triggering
SoundFile tickSound; // Sound file for the clock tick

void setup() {
  fullScreen();
  f = createFont("TimesNewRomanPSMT", 24);
  textFont(f);
  cx = width / 2;
  cy = height / 2;
  secondsRadius = 150;
  lastTime = millis();  // Initialize the lastTime variable

  // Initialize the serial port
  String portName = "/dev/cu.usbserial-01D17D99"; // Use the first available serial port (adjust if necessary)
  myPort = new Serial(this, portName, 9600); // Adjust baud rate to match Arduino
  println(join(Serial.list(), ", "));
  
  // Load the clock tick sound
  tickSound = new SoundFile(this, "ClockTick.wav");
}

void draw() {
  background(0);
  
  // Read data from the serial port
  if (myPort.available() > 0) {
    String data = myPort.readStringUntil('\n'); // Read until newline
    if (data != null) {
      data = trim(data); // Remove whitespace
      if (data.endsWith("mm")) { // Check if valid data
        try {
          float distance = float(data.replace(" mm", "")); // Parse distance
          // Map distance to speedMultiplier (e.g., closer = faster)
          speedMultiplier = map(distance, 100, 2000, 5, 0.5); // Adjust range as needed
          speedMultiplier = constrain(speedMultiplier, 0.5, 5); // Clamp value
        } catch (NumberFormatException e) {
          println("Invalid data: " + data);
        }
      }
    }
  }

  // Calculate deltaTime in seconds
  int currentTime = millis();
  float deltaTime = (currentTime - lastTime) / 1000.0;
  lastTime = currentTime;

  // Update the baseSecond value based on the speed multiplier
  baseSecond += speedMultiplier * deltaTime;
  baseSecond %= 60; // Keep seconds within the range [0, 60)

  // Trigger sound when the second hand moves a full unit
  int currentSecond = floor(baseSecond);
  if (currentSecond != lastSecond) {
    tickSound.play(); // Play the tick sound
    lastSecond = currentSecond;
  }

  translate(cx, cy);
  scale(2.5);
  rotate(-HALF_PI);

  stroke(255);

  // Map seconds to angles
  float s = map(baseSecond, 0, 60, 0, TWO_PI);
  float futureS = map((baseSecond + 4) % 60, 0, 60, 0, TWO_PI);
  float pastS = map((baseSecond - 4 + 60) % 60, 0, 60, 0, TWO_PI); // Ensure pastS stays positive

  // The seconds hand
  pushMatrix();
  strokeWeight(8);
  line(0, 0, cos(s) * secondsRadius, sin(s) * secondsRadius);
  popMatrix();

  // The Future
  pushMatrix();
  textAlign(CENTER);
  translate(cos(futureS) * secondsRadius, sin(futureS) * secondsRadius);
  rotate(HALF_PI);
  text("FUTURE", 0, 0);
  popMatrix();

  // The Past
  pushMatrix();
  textAlign(CENTER);
  translate(cos(pastS) * secondsRadius, sin(pastS) * secondsRadius);
  rotate(HALF_PI);
  text("PAST", 0, 0);
  popMatrix();

  // Display current speed multiplier
  resetMatrix();
  fill(255);
  textAlign(LEFT);
  textSize(20);
  text("Speed Multiplier: " + nf(speedMultiplier, 1, 2) + "x", 10, height - 40);
}
