import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';
import 'dart:math';

RenderingContext gl;
int posAttr;

List<List<int>> map = [
 [1, 2, 0, 2, 4, 0, 0, 0],
 [3, 1, 0, 2, 4, 0, 0, 0],
 [0, 0, 0, 2, 1, 1, 4, 0],
 [0, 0, 0, 0, 1, 1, 1, 1],
 [0, 0, 0, 0, 1, 1, 1, 1],
 [0, 3, 3, 0, 0, 0, 0, 1],
 [0, 3, 3, 0, 0, 0, 0, 1],
 [0, 0, 0, 0, 0, 0, 0, 1],
];

List<List<double>> colors = [
 [0.0, 0.0, 0.0, 1.0],
 [1.0, 0.0, 0.0, 1.0],
 [0.0, 1.0, 0.0, 1.0],
 [0.0, 0.0, 1.0, 1.0],
 [1.0, 1.0, 1.0, 1.0],
];

List<double> makePerspective(fov, aspect, near, far) {
  var f = 1.0 / tan(0.5 * fov * PI / 180);
  var rangeInv = 1.0 / (near - far);

  return [
    f / aspect, 0.0, 0.0, 0.0,
    0.0, f, 0.0, 0.0,
    0.0, 0.0, (near + far) * rangeInv, -1.0,
    0.0, 0.0, near * far * rangeInv * 2.0, 0.0
  ];
}

List<double> makeOrthographic(width, height, near, far) {
  return [
    2.0 / width, 0.0, 0.0, 0.0,
    0.0, -2.0 / height, 0.0, 0.0,
    0.0, 0.0, -2.0 / (far-near), 0.0,
    0.0, 0.0, 0.0, 1.0
  ];
}

List<double> makeViewMatrix(px, py) {
  // this is technically correct, but makes edges look gross
  //var theta_x = 54.736 * PI / 180.0;
  var theta_x = -60.0 * PI / 180.0;
  var theta_z = 45.0 * PI / 180.0;
  var cx = cos(theta_x);
  var sx = sin(theta_x);
  var cz = cos(theta_z);
  var sz = sin(theta_z);
  return [
        cz,  cx*sz, sx*sz, 0.0,
        sz, -cx*cz,-sx*cz, 0.0,
       0.0, -sx,       cx, 0.0,
    px*cz+py*sz, -(-px*cx*sz+py*cx*cz), px*sx*sz+-py*sx*cz-256.0, 1.0
  ];
  /*
  return [
    cz,   cx*sz,  sx*sz, 0.0,
    sz,  -cx*cz, -sx*cz, 0.0,
    0.0, -sx,     cx,    0.0,
    px*cz+py*-cx*sz, px*-sz+py*-cx*cz, -128.0, 1.0
  ];
  */
}

Buffer groundTileBuffer = null;
Buffer createGroundTileBuffer(double size) {
  groundTileBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, groundTileBuffer);
  var vertices = [
    -size, -size, 0.0,
    -size,  size, 0.0,
     size, -size, 0.0,
     size,  size, 0.0
  ];
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);
}

Buffer cornerVertexBuffer = null;
Buffer cornerIndexBuffer = null;
Buffer leftWallIndexBuffer = null;
Buffer rightWallIndexBuffer = null;
Buffer groundIndexBuffer = null;
Buffer createCornerBuffer(double size) {
  cornerVertexBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, cornerVertexBuffer);
  var vertices = [
    -size, -size, 1.62*size, 1.0,
     size, -size, 1.62*size, 1.0,
     size,  size, 1.62*size, 1.0,
    -size, -size, 0.0, 0.25,
     size, -size, 0.0, 0.0,
     size,  size, 0.0, 0.25,
    -size, -size, 0.0, 1.0,
     size, -size, 0.0, 0.25,
     size,  size, 0.0, 1.0,
     size, -size, 0.0, 1.0,
    -size,  size, 0.0, 1.0,
     size, -size, 1.62*size, 0.25,
  ];
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);
  
  cornerIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, cornerIndexBuffer);
  var indices =  [
    0, 11, 4,
    0, 4, 3,
    11, 2, 4,
    4, 2, 5,
    3, 4, 10,
    10,4, 5
  ];
  gl.bufferData(ELEMENT_ARRAY_BUFFER, new Int16List.fromList(indices), STATIC_DRAW);

  leftWallIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, leftWallIndexBuffer);
  indices =  [
    0, 1, 3,
    3, 1, 7,
    3, 7, 8,
    3, 8, 10
  ];
  gl.bufferData(ELEMENT_ARRAY_BUFFER, new Int16List.fromList(indices), STATIC_DRAW);

  rightWallIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, rightWallIndexBuffer);
  indices =  [
    1, 2, 5,
    1, 5, 7,
    6, 7, 5,
    6, 5, 10
  ];
  gl.bufferData(ELEMENT_ARRAY_BUFFER, new Int16List.fromList(indices), STATIC_DRAW);

  groundIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, groundIndexBuffer);
  indices =  [
    6, 9, 8,
    6, 8, 10
  ];
  gl.bufferData(ELEMENT_ARRAY_BUFFER, new Int16List.fromList(indices), STATIC_DRAW);
}


Buffer leftWallBuffer = null;
void createLeftWallBuffer(double size) {
  leftWallBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, leftWallBuffer);
  var vertices = [
     size, -size, 0.0, 0.0,
     size, -size, 1.62*size, 1.0,
    -size, -size, 0.0, 0.0,
    -size, -size, 1.62*size, 1.0
  ];
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);
}

Buffer rightWallBuffer = null;
void createRightWallBuffer(double size) {
  rightWallBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, rightWallBuffer);
  var vertices = [
    size, -size, 0.0, 0.0,
    size, -size, 1.62*size, 1.0,
    size,  size, 0.0, 0.0,
    size,  size, 1.62*size, 1.0
  ];
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);
}

Buffer wireframeBuffer = null;
void createWireframeBuffer(double size) {
  wireframeBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, wireframeBuffer);
  var vertices = [
   -size, -size, 0.0,
    size, -size, 0.0,
    size, -size, 0.0,
    size, -size, -1.62*size,
    size, -size, 0.0,
    size,  size, 0.0,
  ];
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);
}

void drawGround() {
  gl.bindBuffer(ARRAY_BUFFER, cornerVertexBuffer);
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, groundIndexBuffer);
  gl.vertexAttribPointer(posAttr, 4, FLOAT, false, 0, 0);
  gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);
}

void drawCorner() {
  gl.bindBuffer(ARRAY_BUFFER, cornerVertexBuffer);
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, cornerIndexBuffer);
  gl.vertexAttribPointer(posAttr, 4, FLOAT, false, 0, 0);
  gl.drawElements(TRIANGLES, 18, UNSIGNED_SHORT, 0);
}

void drawLeftWall() {
  gl.bindBuffer(ARRAY_BUFFER, cornerVertexBuffer);
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, leftWallIndexBuffer);
  gl.vertexAttribPointer(posAttr, 4, FLOAT, false, 0, 0);
  gl.drawElements(TRIANGLES, 12, UNSIGNED_SHORT, 0);
}

void drawRightWall() {
  gl.bindBuffer(ARRAY_BUFFER, cornerVertexBuffer);
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, rightWallIndexBuffer);
  gl.vertexAttribPointer(posAttr, 4, FLOAT, false, 0, 0);
  gl.drawElements(TRIANGLES, 12, UNSIGNED_SHORT, 0);
}

void drawWireframe(int start, int end) {
  gl.bindBuffer(ARRAY_BUFFER, wireframeBuffer);
  gl.vertexAttribPointer(posAttr, 3, FLOAT, false, 0, 0);
  gl.drawArrays(LINES, start, end-start);
}

List<double> modulate(List<double> color, double factor) {
  return [factor*color[0], factor*color[1], factor*color[2], color[3]];
}

void main() {
  var gamepads = window.navigator.getGamepads();
  var canvas = querySelector("#glcanvas");
  gl = canvas.getContext("experimental-webgl");
  gl.clearColor(0,0,0,1);
  gl.enable(DEPTH_TEST);
  
  createGroundTileBuffer(32.0);
  createLeftWallBuffer(32.0);
  createRightWallBuffer(32.0);
  createWireframeBuffer(32.0);
  createCornerBuffer(32.0);
  
  // vertex shader
  Shader vs = gl.createShader(VERTEX_SHADER);
  gl.shaderSource(vs, """
    precision highp float;
    attribute vec4 aVertexPosition;

    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;
    varying vec3 position;

    void main(void) {
      position = aVertexPosition.xyz;
      gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition.xyz, 1.0);
    }
  """);
  gl.compileShader(vs);
  
  if (!gl.getShaderParameter(vs, COMPILE_STATUS)) {
    window.alert(gl.getShaderInfoLog(vs));
    return null;
  }
  
  // fragment shader
  Shader fs = gl.createShader(FRAGMENT_SHADER);
  gl.shaderSource(fs, """
    #define M_PI 3.1415926535897932384626433832795
    precision highp float;
    uniform vec4 color;
    uniform vec4 ambientOcclusion;  // occlusion factor for each dimension.
    varying vec3 position;

    void main(void) {
      vec4 ao = vec4(
        0.5 * (1.0 + sin((position.y+32.0)/64.0 * M_PI / 2.0)),
        0.5 * (1.0 + sin((-position.x+32.0)/64.0 * M_PI / 2.0)),
        (1.0 + sin((position.z)/(1.62*32.0) * M_PI / 2.0)),
        1.0);
      ao = mix(vec4(1.0), ao, ambientOcclusion);
      ao = pow(ao, vec4(1.25));
      //gl_FragColor = color * vec4(vec3(mix(1.0, pow(ao.x, 1.2), ambientOcclusion.x)*mix(1.0, pow(ao.y, 1.2), ambientOcclusion.y)), 1.0);
      gl_FragColor = color * vec4(vec3(ao.x*ao.y*ao.z), 1.0);
    }
  """);
  gl.compileShader(fs);
  
  if (!gl.getShaderParameter(fs, COMPILE_STATUS)) {
    window.alert(gl.getShaderInfoLog(fs));
    return null;
  }
  
  Program program = gl.createProgram();
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);
  
  if (!gl.getProgramParameter(program, LINK_STATUS)) {
    window.alert("Could not initialise shaders");
  }
  
  posAttr = gl.getAttribLocation(program, "aVertexPosition");
  gl.enableVertexAttribArray(posAttr);
  UniformLocation pMatrixUniform = gl.getUniformLocation(program, "uPMatrix");
  UniformLocation mvMatrixUniform = gl.getUniformLocation(program, "uMVMatrix");
  UniformLocation color = gl.getUniformLocation(program, "color");
  UniformLocation ambientOcclusion = gl.getUniformLocation(program, "ambientOcclusion");
  
  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clear(RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);

  
  var pMatrix = makePerspective(60, canvas.width / canvas.height, 0.1, 1000.0);
  //var pMatrix = makeOrthographic(canvas.width, canvas.height, 0.1, 1000.0);
  
  gl.useProgram(program);
  gl.uniformMatrix4fv(pMatrixUniform, false, new Float32List.fromList(pMatrix));


  var mvMatrix;
  
  // need to iterate in diamond rows
//  for(int y = 0; y < map.length; y++) {
//    for(int x = 0; x < map[y].length; x++) {
  for(int y = 0; y < 2; y++) {
    for(int x = 0; x < 2; x++) {
      if(map[y][x] == 0)
        continue;

      //mvMatrix = makeViewMatrix((x - map[y].length / 2 + 0.5).toDouble() * 64.0, (y - map.length / 2 + 0.5).toDouble() * 64.0);
      mvMatrix = makeViewMatrix(x.toDouble()*64.0, y.toDouble()*64.0);
      
      bool leftWall = (y-1 < 0 || map[y-1][x] == 0);
      bool rightWall = (x+1 >= map[y].length || map[y][x+1] == 0);

      if(leftWall && rightWall) {
        gl.uniform4fv(color, new Float32List.fromList(modulate(colors[map[y][x]], 0.8)));
        gl.uniform4fv(ambientOcclusion, new Float32List.fromList([1.0,1.0,1.0,0.0]));
        gl.uniformMatrix4fv(mvMatrixUniform, false, new Float32List.fromList(mvMatrix));
        drawCorner();
      }
      else if(leftWall) {
        gl.uniform4fv(color, new Float32List.fromList(modulate(colors[map[y][x]], 0.8)));
        gl.uniform4fv(ambientOcclusion, new Float32List.fromList([1.0,0.0,1.0,0.0]));
        gl.uniformMatrix4fv(mvMatrixUniform, false, new Float32List.fromList(mvMatrix));
        drawLeftWall();
      }
      else if(rightWall) {
        gl.uniform4fv(color, new Float32List.fromList(modulate(colors[map[y][x]], 0.65)));
        gl.uniform4fv(ambientOcclusion, new Float32List.fromList([0.0,1.0,1.0,0.0]));
        gl.uniformMatrix4fv(mvMatrixUniform, false, new Float32List.fromList(mvMatrix));
        drawRightWall();
      }
      else {
        gl.uniform4fv(color, new Float32List.fromList(modulate(colors[map[y][x]], 1.0)));
        gl.uniform4fv(ambientOcclusion, new Float32List.fromList([0.0,0.0,1.0,0.0]));
        gl.uniformMatrix4fv(mvMatrixUniform, false, new Float32List.fromList(mvMatrix));
        drawGround();
      }
    }
  }
}
