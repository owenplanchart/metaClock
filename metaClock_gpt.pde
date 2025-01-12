int cx, cy;
float secondsRadius;
PFont f;
float baseSecond = 0;  // Tracks the current second with speed adjustments
float speedMultiplier = 1;  // Speed factor controlled by mouseX
int lastTime;  // Tracks the time of the previous frame

void setup() {
  fullScreen();
  f = createFont("TimesNewRomanPSMT", 24);
  textFont(f);
  cx = width / 2;
  cy = height / 2;
  secondsRadius = 150;
  lastTime = millis();  // Initialize the lastTime variable
  
//  String[] fonts = PFont.list();
//for (String font : fonts) {
//    println(font);
//}

}

void draw() {
  background(0);

  // Calculate deltaTime in seconds
  int currentTime = millis();
  float deltaTime = (currentTime - lastTime) / 1000.0;
  lastTime = currentTime;

  // Map mouseX to control the speed multiplier
  speedMultiplier = map(mouseX, 0, width, 1, 5); // Adjust range as needed

  // Update the baseSecond value based on the speed multiplier
  baseSecond += speedMultiplier * deltaTime;
  baseSecond %= 60; // Keep seconds within the range [0, 60)

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
