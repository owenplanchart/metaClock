import processing.serial.*;
import processing.sound.*;

Serial myPort;  // Serial port for Arduino
int cx, cy;
float secondsRadius;
PFont f;
float baseSecond = 0;  // Tracks the current second with speed adjustments
float speedMultiplier = 1;  // Speed factor for the second hand
int lastTime;  // Tracks the time of the previous frame
int lastSecond = 0; // Tracks the last integer second for sound triggering
SoundFile tickSound; // Sound file for the clock tick
boolean mouseControl = true; // Track whether mouse control is active (default)

void setup() {
  fullScreen();
  f = createFont("TimesNewRomanPSMT", 24);
  textFont(f);
  cx = width / 2;
  cy = height / 2;
  secondsRadius = 150;
  lastTime = millis();  // Initialize the lastTime variable

  // Load the clock tick sound
  tickSound = new SoundFile(this, "ClockTick.wav");

  // Attempt to initialize the serial port
  try {
    String portName = "/dev/cu.usbserial-01D17D99"; // Replace with the appropriate port
    myPort = new Serial(this, portName, 9600); // Adjust baud rate to match Arduino
    mouseControl = false; // Switch to sensor control if the serial port is successfully opened
    println("Sensor connected. Using sensor control.");
  } catch (Exception e) {
    println("Sensor not connected. Defaulting to mouse control.");
    mouseControl = true; // Default to mouse control if sensor connection fails
  }
}

void draw() {
  background(0);

  // Handle data from the serial port only if sensor control is active and the serial port is initialized
  if (!mouseControl && myPort != null && myPort.available() > 0) {
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

  // If mouse control is active, map mouseX to speedMultiplier
  if (mouseControl) {
    speedMultiplier = map(mouseX, 0, width, 1, 5); // Adjust range as needed
    speedMultiplier = constrain(speedMultiplier, 0.5, 5); // Clamp value
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

  // Display current speed multiplier and mode
  resetMatrix();
  fill(255);
  textAlign(LEFT);
  textSize(20);
  text("Speed Multiplier: " + nf(speedMultiplier, 1, 2) + "x", 10, height - 60);
  text("Mode: " + (mouseControl ? "Mouse Control" : "Sensor Control"), 10, height - 40);
}

void keyPressed() {
  // Toggle between mouse and sensor control when 'm' is pressed
  if (key == 'm' || key == 'M') {
    mouseControl = !mouseControl;
    println("Mode switched to: " + (mouseControl ? "Mouse Control" : "Sensor Control"));
  }
}

 
