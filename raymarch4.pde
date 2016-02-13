void setup(){
  size(200, 200);
  noLoop();
}

// how many frames to render
int foof = 0;
int maxfoof = 49;

float pillarMove = 0;

void draw(){
  background(0);
  render(cam);
  
  pillarMove += 0.8485/25; 
  cam.pos.z += 0.24;
  
  /*
  // saves rendered frames for making gifs
  foof++;
  if(foof > maxfoof){
    noLoop();
  }
  
  saveFrame("pillars-######.png");
  //*/
}

// SCENE AND CAMERA

int maxSteps = 60; // the maximum number of steps a ray will travel.  Higher numbers are expensive, but necessary to render complex scenes.
float minStep = 0.002f; // the minimum distance a ray is permitted to travel at each step.  Higher numbers improve performance at the cost of accuracy.
float accuracy = 0.0001f; // the distance from a ray to a surface that qualifies as a hit.  Smaller numbers are more accurate & more expensive.

// I haven't done much with lighting yet
// right now the raymarcher only supports basic diffuse shading from a single point light
PVector lightPos = new PVector(0, 0, 0);
color lightColor = #8822bb;

color ambientColor = #333333;

Camera cam = new Camera(); // instance of the camera object

// an object to store all camera variables

class Camera{
  // camera position & orientation
  PVector pos = new PVector(0, 0, 0);
  PVector up = new PVector(0, 1, 0);
  PVector right = new PVector(1, 0, 0);
  PVector forward = new PVector(0, 0, 1);
  
  // focal length
  float f = 0.6;
  
  // environment
  float nearClip = 0;
  float farClip = 32;
  float fogStart = 6;
  color fogColor = #001122;
}

// the distance field itself
// this can be thought of as the scene to be rendered
// it consists of a collection of distance functions, each representing an object in space
// it returns the distance to the nearest object from any arbitrary point

float scene(PVector p){
  
  float d1 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(6.5, 0, 0)), new PVector(pillarMove, -pillarMove, 0)), 45), new PVector(0.3, 0.2, 0.3), new PVector(6, 0.6, 6));
  float d2 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(6.5, 0, 0)), new PVector(pillarMove, -pillarMove, 0)), 45), new PVector(0.2, 5, 0.2), new PVector(6, 1, 6));
  
  float d3 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(-6.5, 0, 0)), new PVector(-pillarMove, pillarMove, 0)), 45), new PVector(0.3, 0.2, 0.3), new PVector(6, 0.6, 6));
  float d4 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(-6.5, 0, 0)), new PVector(-pillarMove, pillarMove, 0)), 45), new PVector(0.2, 5, 0.2), new PVector(6, 1, 6));
  
  float d5 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(6.5, 0, 0)), new PVector(-pillarMove, -pillarMove, 3)), 135), new PVector(0.3, 0.2, 0.3), new PVector(6, 0.6, 6));
  float d6 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(6.5, 0, 0)), new PVector(-pillarMove, -pillarMove, 3)), 135), new PVector(0.2, 5, 0.2), new PVector(6, 1, 6));
  
  float d7 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(-6.5, 0, 0)), new PVector(pillarMove, pillarMove, 3)), 135), new PVector(0.3, 0.2, 0.3), new PVector(6, 0.6, 6));
  float d8 = sdRepBoxes(rotateZ(PVector.add(PVector.add(p, new PVector(-6.5, 0, 0)), new PVector(pillarMove, pillarMove, 3)), 135), new PVector(0.2, 5, 0.2), new PVector(6, 1, 6));
  
  return smin(smin(smin(d1, d2, 0.1), smin(d3, d4, 0.1), 0.1), smin(smin(d5, d6, 0.1), smin(d7, d8, 0.1), 0.1), 01);
}

// CORE FUNCTIONS

void render(Camera cam){
  loadPixels();
  
  for(int y = 0; y < height; y++){
    for(int x = 0; x < width; x++){
      float u = map(x, 0, width-1, -1, 1);
      float v = map(y, 0, height-1, -1, 1);
      
      float aspectRatio = (float)width/height;
      
      // mirror x
      //u = Math.abs(u);
      
      // mirror y
      //v = Math.abs(v);
      
      PVector rayOrigin = cam.pos;
      PVector rayDirection = PVector.add(PVector.add(PVector.mult(cam.forward, cam.f), PVector.mult(cam.right, u * aspectRatio)), PVector.mult(cam.up, v)).normalize();
      
      rmData rm = raymarch(rayOrigin, rayDirection, cam.farClip);
      float t = rm.t;
      int i = rm.i;
      PVector p = rm.hit;
      
      pixels[x + y * width] = getColor(cam, p, t, i);
    }
  }
  
  updatePixels();
}

// the raymarch function itself

rmData raymarch(PVector ro, PVector rd, float maxDist){
  float totalDistance = 0f;
  int i = 0;
  PVector p = ro;
  
  for(i = 0; i < maxSteps; i++){
    p = PVector.add(ro, PVector.mult(rd, totalDistance));
    
    float distance = scene(p);
    
    if(distance < accuracy || distance >= maxDist){
      break;
    }
    
    totalDistance += Math.max(distance, minStep);
  }
  
  return new rmData(totalDistance, i, p);
}

// a container object for the data returned by the raymarch function

class rmData{
  float t;
  int i;
  PVector hit;
  
  rmData(float distance, int iterations, PVector point){
    t = distance;
    i = iterations;
    hit = point;
  }
}

// this function uses the raymarch data to compute the color of each pixel
// the final image is created by blending various render passes

color getColor(Camera cam, PVector p, float t, int i){
  if(t >= cam.farClip || i >= maxSteps){
    // a ray which has exceeded the maximum number of steps is normally treated as if it hadn't hit anything
    // commenting out the second condition in this if statement means that it will instead be treated as if it had hit whichever object was nearest
    // the result is an interesting "glorpy" effect that allows you to see the far bound of the raymarcher as if it were a sort of membrane, vacuum sealing around objects
    return cam.fogColor;
  }
  
  color col = ambientColor;
  
  PVector normal = getNormal(p);
  float zDepth = map(t, cam.nearClip, cam.farClip, 0, 1);
  
  // my first attempt at making normal maps creates some interesting glitches, so I left it in
  //col = color((getNormal(p).x+1) * 255/2, (getNormal(p).y+1) * 255/2, (getNormal(p).z)+1) * 255/2;
  
  // generates normal map
  //col = color(-(normal.x - 1) * 255/2, -(normal.y - 1) * 255/2, -(normal.z - 1) * 255/2);
  
  // zDepth pass
  col = lerpColor(#ff9966, #44ddff, zDepth);
  
  // color by raymarch iterations
  col = blendColor(col, lerpColor(#ffffff, #770044, (float)i/maxSteps), MULTIPLY);
  
  // diffuse shading
  /*
  PVector lightDirection = PVector.sub(lightPos, p).normalize();
  float intensity = clamp(PVector.dot(normal, lightDirection), 0, 1);
  
  col = blendColor(col, lerpColor(#000000, lightColor, intensity), SCREEN);
  //*/
  
  // adds distance fog
  //*
  float fogIntensity = clamp(map(t, cam.fogStart, cam.farClip, 0, 1), 0, 1);
  col = lerpColor(col, cam.fogColor,fogIntensity);
  //*/
  
  return col;
}

// approximates the normal of a surface
// this works by sampling several points near the intersection point
// whichever direction 

PVector getNormal(PVector p){
  float h = 0.001f;
  
  return new PVector(
    scene(p.add(new PVector(h, 0, 0))) - scene(p.sub(new PVector(h, 0, 0))),
    scene(p.add(new PVector(0, h, 0))) - scene(p.sub(new PVector(0, h, 0))),
    scene(p.add(new PVector(0, 0, h))) - scene(p.sub(new PVector(0, 0, h)))).normalize();
}

// DISTANCE FUNCTIONS (representations of objects in space)

float sdRepSpheres(PVector p, float r, PVector s){
  PVector foo = new PVector((Math.abs(p.x) % s.x) - 0.5*s.x, (Math.abs(p.y) % s.y) - 0.5*s.y, (Math.abs(p.z) % s.z) - 0.5*s.z);
  return sdSphere(foo, r);
}

float sdSphere(PVector p, float r){
  return p.mag() - r;
}

float sdRepBoxes(PVector p, PVector size, PVector s){
  PVector foo = new PVector((Math.abs(p.x) % s.x) - 0.5*s.x, (Math.abs(p.y) % s.y) - 0.5*s.y, (Math.abs(p.z) % s.z) - 0.5*s.z);
  return sdBox(foo, size);
}

float udBox(PVector p, PVector size){
  PVector dist = new PVector(Math.max(Math.abs(p.x) - size.x, 0), Math.max(Math.abs(p.y) - size.y, 0), Math.max(Math.abs(p.z) - size.z, 0));
  return dist.mag();
}

float sdBox(PVector p, PVector size){
  PVector d = new PVector(Math.abs(p.x) - size.x, Math.abs(p.y) - size.y, Math.abs(p.z) - size.z);
  return Math.min(Math.max(d.x, Math.max(d.y, d.z)), 0f) + udBox(p, size);
}

// TRANSFORMS

PVector rotateX(PVector p, float d){
  float r = d / (float)(180/Math.PI);
  
  float cosR = (float)Math.cos(r);
  float sinR = (float)Math.sin(r);
  return new PVector(p.x, p.y * cosR - p.z * sinR, p.y * sinR + p.z * cosR);
}
PVector rotateY(PVector p, float d){
  float r = d / (float)(180/Math.PI);
  
  float cosR = (float)Math.cos(r);
  float sinR = (float)Math.sin(r);
  return new PVector(p.x * cosR + p.z * sinR, p.y, -p.x * sinR + p.z * cosR);
}
PVector rotateZ(PVector p, float d){
  float r = d / (float)(180/Math.PI);
  
  float cosR = (float)Math.cos(r);
  float sinR = (float)Math.sin(r);
  return new PVector(p.x * cosR + p.y * sinR, -p.x * sinR + p.y * cosR, p.z);
}

// EXTRA FUNCTIONS

float mix(float a, float b, float h){
  return a*(1-h)+b*h;
}

float clamp(float input, float min, float max){
  if(input < min){
    return min;
  }
  else if(input > max){
    return max;
  }
  else {
    return input;
  }
}

// polynomial smooth min (k = 0.1);
// used for smoothly blending together intersecting objects
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}