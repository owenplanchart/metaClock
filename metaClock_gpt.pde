import processing.serial.*;
import processing.sound.*;

// We'll define a single constant for the maximum slice angle
final float MAX_SLICE_ANGLE = radians(70);

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
    String portName = "/dev/cu.usbserial-01D17D99";
    myPort = new Serial(this, portName, 9600);
    mouseControl = false; // Switch to sensor control if the serial port is successfully opened
    println("Sensor connected. Using sensor control.");
  }
  catch (Exception e) {
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
      if (data.endsWith("mm")) {
        try {
          float distance = float(data.replace(" mm", ""));
          println("distance: " + distance);

          // Far distance => faster speed => narrower fan
          // Close distance => slower speed => wider fan
          // We'll keep the 1600 range for sensor mapping.
          speedMultiplier = map(distance, 100, 1600, 0.5, 5);
          speedMultiplier = constrain(speedMultiplier, 0.5, 5);

          // Smooth the sensor distance:
          if (firstSensorRead) {
            smoothedDistance = distance; // initialize
            firstSensorRead = false;
          } else {
            float alpha = 0.2; // 20% new reading, 80% old
            smoothedDistance = alpha * distance + (1 - alpha) * smoothedDistance;
          }

          // Map smoothed distance to sliceAngle, from MAX_SLICE_ANGLE at close to 0 at far
          float newSliceAngle = map(smoothedDistance, 100, 1600, MAX_SLICE_ANGLE, 0);
          newSliceAngle = constrain(newSliceAngle, 0, MAX_SLICE_ANGLE);
          sliceAngle = newSliceAngle;
        }
        catch (NumberFormatException e) {
          println("Invalid data: " + data);
        }
      }
    }
  }

  // If mouse control is active, override speedMultiplier and sliceAngle based on mouseX
  if (mouseControl) {
    // Reverse logic: x=left => far dist => 2000, x=right => near dist => 100
    float distValue = map(mouseX, 0, width, 2000, 100);

    speedMultiplier = map(distValue, 100, 2000, 0.5, 5);
    speedMultiplier = constrain(speedMultiplier, 0.5, 5);

    // Now map it to up to MAX_SLICE_ANGLE
    float newSliceAngle = map(distValue, 100, 2000, MAX_SLICE_ANGLE, 0);
    sliceAngle = constrain(newSliceAngle, 0, MAX_SLICE_ANGLE);
  }

  // Calculate deltaTime in seconds
  int currentTime = millis();
  float deltaTime = (currentTime - lastTime) / 1000.0;
  lastTime = currentTime;

  // Update baseSecond based on speed multiplier
  baseSecond += speedMultiplier * deltaTime;
  baseSecond %= 60;

  // Trigger sound at integer seconds
  int currentSecond = floor(baseSecond);
  if (currentSecond != lastSecond) {
    tickSound.play();
    lastSecond = currentSecond;
  }

  // Move to center, scale, rotate so 0 is at top
  translate(cx, cy);
  scale(2.5);
  rotate(-HALF_PI);

  float s = map(baseSecond, 0, 60, 0, TWO_PI);

  //////////////////////////////////
  // TEXT OFFSETS TIED TO MAX ANGLE
  //////////////////////////////////
  // Convert the sliceAngle to degrees
  float sliceAngleDeg = degrees(sliceAngle);

  // We'll define variables for FUTURE and PAST offsets
  float futureOffset;
  float pastOffset;

  // FUTURE offset
  if (sliceAngleDeg <= 80) {
    // For 0..80°, map linearly from (0..80 => 4..10)
    futureOffset = map(sliceAngleDeg, 0, 80, 4, 10);
  } else {
    // Beyond 80°, add 0.2 per degree above 80
    // So +10 at 80°, +12 at 90°, +14 at 100°, etc.
    futureOffset = 10 + 0.2 * (sliceAngleDeg - 80);
  }

  // PAST offset
  if (sliceAngleDeg <= 80) {
    // For 0..80°, map linearly from (0..80 => -4..-8)
    pastOffset = map(sliceAngleDeg, 0, 80, -4, -8);
  } else {
    // Beyond 80°, subtract 0.2 per degree above 80
    // So −8 at 80°, −10 at 90°, −12 at 100°, etc.
    pastOffset = -8 - 0.2 * (sliceAngleDeg - 80);
  }

  // Now convert these offsets into angles for FUTURE and PAST text:
  float futureS = map((baseSecond + futureOffset + 60) % 60, 0, 60, 0, TWO_PI);
  float pastS   = map((baseSecond + pastOffset   + 60) % 60, 0, 60, 0, TWO_PI);

  //////////////////////////////////
  // DRAW THE WEDGE
  //////////////////////////////////

  // We'll keep the 60 deg chord inside, outer arc up to sliceAngle
  float INSIDE_CHORD_ANGLE = radians(60);
  float insideHalfAngle = INSIDE_CHORD_ANGLE / 2.0;

  fill(255);
  noStroke();

  float innerRadius = 8;
  float outerRadius = secondsRadius;

  float insideStart = s - insideHalfAngle;
  float insideEnd   = s + insideHalfAngle;

  float outsideHalfAngle = sliceAngle / 2.0;
  float outsideStart = s - outsideHalfAngle;
  float outsideEnd   = s + outsideHalfAngle;

  beginShape();
  // 1) Move to the inside chord start
  vertex(cos(insideStart) * innerRadius, sin(insideStart) * innerRadius);

  // 2) Trace the outer arc
  if (outsideStart < outsideEnd) {
    float step = radians(0.5);
    for (float a = outsideStart; a <= outsideEnd; a += step) {
      vertex(cos(a) * outerRadius, sin(a) * outerRadius);
    }
  } else {
    vertex(cos(s) * outerRadius, sin(s) * outerRadius);
  }

  // 3) Return to the inside chord end
  vertex(cos(insideEnd) * innerRadius, sin(insideEnd) * innerRadius);

  endShape(CLOSE);

  // Now draw the seconds hand
  //stroke(255);
  //strokeWeight(8);
  //line(0, 0, cos(s) * (secondsRadius - 4), sin(s) * (secondsRadius - 4));

  // The Future
  pushMatrix();
  textAlign(CENTER);
  fill(255);
  translate(cos(futureS) * secondsRadius + 20, sin(futureS) * secondsRadius);
  rotate(HALF_PI);
  text("FUTURE", 0, 0);
  popMatrix();

  // The Past
  pushMatrix();
  textAlign(CENTER);
  fill(255);
  translate(cos(pastS) * secondsRadius, sin(pastS) * secondsRadius);
  rotate(HALF_PI);
  text("PAST", 0, 0);
  popMatrix();

  // Reset transform
  resetMatrix();
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("Speed Multiplier: " + nf(speedMultiplier, 1, 2) + "x", 10, height - 60);
  text("Mode: " + (mouseControl ? "Mouse Control" : "Sensor Control"), 10, height - 40);

  // Store the sliceAngle for next frame
  oldSliceAngle = sliceAngle;
}

void keyPressed() {
  if (key == 'm' || key == 'M') {
    // If we are about to switch from mouse -> sensor
    if (mouseControl) {
      // We were in mouse mode, now toggling to sensor mode
      if (myPort != null) {
        myPort.clear(); // Clear any stale data
      }
      firstSensorRead = true; // Next sensor reading updates smoothedDistance immediately
    }

    mouseControl = !mouseControl;
    println("Mode switched to: " + (mouseControl ? "Mouse Control" : "Sensor Control"));
  }
}
