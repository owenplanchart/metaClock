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
  }
  catch (Exception e) {
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
        }
        catch (NumberFormatException e) {
          println("Invalid data: " + data);
        }
      }
    }
  }

  // If mouse control is active, map mouseX to speedMultiplier and slice thickness
  float sliceAngle = 0; // The angle of the slice (starts as a line)
  if (mouseControl) {
    speedMultiplier = map(mouseX, 0, width, 5, 0.5); // Inverted range
    speedMultiplier = constrain(speedMultiplier, 0.5, 5); // Clamp value

    // Map mouseX to slice angle (0 for a line, up to 45 degrees)
    sliceAngle = map(mouseX, 0, width, radians(0), radians(45));
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

  // Map seconds to angles
  float s = map(baseSecond, 0, 60, 0, TWO_PI);
 // Adjust future and past angles based on mouse position
  float futureOffset = map(mouseX, 0, width, 4, 8); // Varies between +4 and +8
  float pastOffset = map(mouseX, 0, width, -4, -6); // Varies between -6 and -4

  float futureS = map((baseSecond + futureOffset + 60) % 60, 0, 60, 0, TWO_PI); // Ensure valid range
  float pastS = map((baseSecond + pastOffset + 60) % 60, 0, 60, 0, TWO_PI);   // Ensure valid range

  // Draw the expanding pie slice
  float arcStart = s - sliceAngle / 2; // Start angle of the slice
  float arcEnd = s + sliceAngle / 2;   // End angle of the slice
  if (sliceAngle > 0) {
    fill(255); // Solid white color for the slice
    noStroke();

    // Inner and outer radii for the slice
    float innerRadius = 8; // Start near the center
    float outerRadius = secondsRadius;    // Match the outer circle boundary

    // Draw the fan-shaped slice with an arc for the outer edge
    beginShape();

    // Inner edge
    vertex(cos(arcStart) * innerRadius, sin(arcStart) * innerRadius);

    // Outer arc
    for (float a = arcStart; a <= arcEnd; a += radians(0.5)) { // Smaller step size for smoother arc
      vertex(cos(a) * outerRadius, sin(a) * outerRadius);
    }

    // Inner edge (back to the other side)
    vertex(cos(arcEnd) * innerRadius, sin(arcEnd) * innerRadius);

    endShape(CLOSE);
  }

  // Draw the original seconds hand as a line
  stroke(255);
  strokeWeight(8);
  line(0, 0, cos(s) * (secondsRadius - 4), sin(s) * (secondsRadius - 4));

  // The Future and Past remain unchanged...






  // The Future
  pushMatrix();
  textAlign(CENTER);
  fill(255); // Make sure text is fully visible
  translate(cos(futureS) * secondsRadius + 20, sin(futureS) * secondsRadius);
  rotate(HALF_PI);
  text("FUTURE", 0, 0);
  popMatrix();

  // The Past
  pushMatrix();
  textAlign(CENTER);
  fill(255); // Make sure text is fully visible
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
