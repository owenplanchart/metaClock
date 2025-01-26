import processing.serial.*;
import processing.sound.*;

Serial myPort;  // Serial port for Arduino
int cx, cy;
float secondsRadius;
PFont f;

float baseSecond = 0;  // Tracks the current second with speed adjustments
float speedMultiplier = 1;  // Speed factor for the second hand

int lastTime;    // Tracks the time of the previous frame (millis)
int lastSecond = 0; // Tracks the last integer second for sound triggering

SoundFile tickSound; // Sound file for the clock tick
boolean mouseControl = true; // Track whether mouse control is active (default)

// We'll keep a global smoothed distance for sensor data.
float smoothedDistance = 1500;   // starting guess if you want.
boolean firstSensorRead = true; // track whether we set it once

// We'll also keep the sliceAngle across frames.
float sliceAngle = 0;
float oldSliceAngle = 0;

void setup() {
  // Use a window during development so you can see console messages.
  // When confident everything works, switch to fullScreen().
  // size(800, 600);
  fullScreen();

  f = createFont("TimesNewRomanPSMT", 24);
  textFont(f);

  cx = width / 2;
  cy = height / 2;
  secondsRadius = 150;
  lastTime = millis();  // Initialize the lastTime

  // Load the clock tick sound
  tickSound = new SoundFile(this, "ClockTick.wav");

  // Attempt to initialize the serial port
  try {
    // Replace with the correct port, or use Serial.list() to see your options
    String portName = "/dev/cu.usbserial-01D17D99";
    myPort = new Serial(this, portName, 9600);
    mouseControl = false; // Switch to sensor control if the serial port is successfully opened
    println("Sensor connected. Using sensor control.");
  } catch (Exception e) {
    println("Sensor not connected. Defaulting to mouse control.");
    mouseControl = true;
  }
}

void draw() {
  background(0);

  // By default, keep sliceAngle from the previous frame.
  // (We update it if new sensor data arrives or if in mouse mode.)
  sliceAngle = oldSliceAngle;

  // Handle data from the serial port only if sensor control is active
  if (!mouseControl && myPort != null && myPort.available() > 0) {
    String data = myPort.readStringUntil('\n'); // Read until newline
    if (data != null) {
      data = trim(data); // Remove whitespace
      if (data.endsWith("mm")) { // Check if valid data
        try {
          float distance = float(data.replace(" mm", "")); // Parse distance
          println("distance: " + distance);

          // Far distance => faster speed => narrower fan
          // Close distance => slower speed => wider fan
          // Let's keep the 1600 range for this example (adjust as needed)
          speedMultiplier = map(distance, 100, 1600, 0.5, 5);
          speedMultiplier = constrain(speedMultiplier, 0.5, 5);

          // Smooth the sensor distance:
          if (firstSensorRead) {
            smoothedDistance = distance; // initialize
            firstSensorRead = false;
          } else {
            // alpha = 0.2 => 20% new reading, 80% old reading
            float alpha = 0.2;
            smoothedDistance = alpha * distance + (1 - alpha) * smoothedDistance;
          }

          // Map the smoothed distance to sliceAngle, from 80 deg at close to 0 deg at far
          float newSliceAngle = map(smoothedDistance, 100, 1600, radians(80), radians(0));
          newSliceAngle = constrain(newSliceAngle, 0, radians(80));
          sliceAngle = newSliceAngle;
        } catch (NumberFormatException e) {
          println("Invalid data: " + data);
        }
      }
    }
  }

  // If mouse control is active, override speedMultiplier and sliceAngle based on mouseX
  if (mouseControl) {
    // Reverse the logic for the mouse so that: mouseX = right => big angle (like short distance)
    // i.e. at x=0 => far (distance=2000), at x=width => near (distance=100)
    float distValue = map(mouseX, 0, width, 2000, 100);

    speedMultiplier = map(distValue, 100, 2000, 0.5, 5);
    speedMultiplier = constrain(speedMultiplier, 0.5, 5);

    // Now map it to up to 80 degrees
    float newSliceAngle = map(distValue, 100, 2000, radians(80), radians(0));
    sliceAngle = constrain(newSliceAngle, 0, radians(80));
  }

  // Calculate deltaTime in seconds
  int currentTime = millis();
  float deltaTime = (currentTime - lastTime) / 1000.0;
  lastTime = currentTime;

  // Update baseSecond based on the speed multiplier
  baseSecond += speedMultiplier * deltaTime;
  baseSecond %= 60; // keep seconds in [0, 60)

  // Trigger sound when the second hand crosses an integer second
  int currentSecond = floor(baseSecond);
  if (currentSecond != lastSecond) {
    tickSound.play();
    lastSecond = currentSecond;
  }

  // Draw clock elements
  translate(cx, cy);
  scale(2.5);
  rotate(-HALF_PI);

  float s = map(baseSecond, 0, 60, 0, TWO_PI);

  // Instead of using mouseX for offsets, tie them to sliceAngle.
  // sliceAngle goes [0..80 deg] => let's map that to [0..1] for normalizing.
  float angleNorm = map(sliceAngle, 0, radians(80), 0, 1);
  // Then we push FUTURE further out as the fan expands, PAST further out as well.
  float futureOffset = map(angleNorm, 0, 1, 4, 10);
  float pastOffset   = map(angleNorm, 0, 1, -4, -8);

  float futureS = map((baseSecond + futureOffset + 60) % 60, 0, 60, 0, TWO_PI);
  float pastS   = map((baseSecond + pastOffset   + 60) % 60, 0, 60, 0, TWO_PI);

  // Draw the expanding pie slice
  if (sliceAngle > 0) {
    fill(255);
    noStroke();

    float innerRadius = 8;
    float outerRadius = secondsRadius;

    float arcStart = s - sliceAngle / 2;
    float arcEnd   = s + sliceAngle / 2;

    beginShape();
    // Move to the inner edge at arcStart
    vertex(cos(arcStart) * innerRadius, sin(arcStart) * innerRadius);

    // Outer arc from arcStart to arcEnd
    for (float a = arcStart; a <= arcEnd; a += radians(0.5)) {
      vertex(cos(a) * outerRadius, sin(a) * outerRadius);
    }

    // Move back to the inner edge at arcEnd
    vertex(cos(arcEnd) * innerRadius, sin(arcEnd) * innerRadius);
    endShape(CLOSE);
  }

  // Draw the seconds hand
  stroke(255);
  strokeWeight(8);
  line(0, 0, cos(s) * (secondsRadius - 4), sin(s) * (secondsRadius - 4));

  // The Future: place it using futureS
  pushMatrix();
    textAlign(CENTER);
    fill(255);
    translate(cos(futureS) * secondsRadius + 20, sin(futureS) * secondsRadius);
    rotate(HALF_PI);
    text("FUTURE", 0, 0);
  popMatrix();

  // The Past: place it using pastS
  pushMatrix();
    textAlign(CENTER);
    fill(255);
    translate(cos(pastS) * secondsRadius, sin(pastS) * secondsRadius);
    rotate(HALF_PI);
    text("PAST", 0, 0);
  popMatrix();

  // Reset transform to draw text on screen
  resetMatrix();
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("Speed Multiplier: " + nf(speedMultiplier, 1, 2) + "x", 10, height - 60);
  text("Mode: " + (mouseControl ? "Mouse Control" : "Sensor Control"), 10, height - 40);

  // Finally, store the sliceAngle for next frame so we don't flicker.
  oldSliceAngle = sliceAngle;
}

void keyPressed() {
  // Toggle between mouse and sensor control when 'm' is pressed
  if (key == 'm' || key == 'M') {
    mouseControl = !mouseControl;
    println("Mode switched to: " + (mouseControl ? "Mouse Control" : "Sensor Control"));
  }
}
