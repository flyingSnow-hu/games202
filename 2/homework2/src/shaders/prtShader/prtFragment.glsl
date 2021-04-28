#ifdef GL_ES
precision mediump float;
#endif

uniform mat3 uPrecomputeLR;
uniform mat3 uPrecomputeLG;
uniform mat3 uPrecomputeLB;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp mat3 vPrecomputeLT;

float SH00() {
  return 0.282095;
}

float SH1n1(vec3 dir) {
  return -0.488603 * dir.y;
}

float SH10(vec3 dir) {
  return 0.488603 * dir.z;
}

float SH1p1(vec3 dir) {
  return -0.488603 * dir.x;
}

float SH2n2(vec3 dir) {
  return 1.092548 * dir.x * dir.y;
}

float SH2n1(vec3 dir) {
  return -1.092548 * dir.y * dir.z;
}

float SH20(vec3 dir) {
  return 0.315392 * (-dir.x * dir.x - dir.y * dir.y + 2.0 * dir.z * dir.z);
}

float SH2p1(vec3 dir) {
  return -1.092548 * dir.x * dir.z;
}

float SH2p2(vec3 dir) {
  return 0.546274 * (dir.x * dir.x - dir.y * dir.y);
}

void main_() {
    vec3 ret = 
        SH00()         * vPrecomputeLT[0][0] * SH00()         *  vec3(uPrecomputeLR[0][0], uPrecomputeLG[0][0], uPrecomputeLB[0][0]) + 
        SH1n1(vNormal) * vPrecomputeLT[0][1] * SH1n1(vNormal) *  vec3(uPrecomputeLR[0][1], uPrecomputeLG[0][1], uPrecomputeLB[0][1]) + 
        SH10(vNormal)  * vPrecomputeLT[0][2] * SH10(vNormal)  *  vec3(uPrecomputeLR[0][2], uPrecomputeLG[0][2], uPrecomputeLB[0][2]) + 
        SH1p1(vNormal) * vPrecomputeLT[1][0] * SH1p1(vNormal) *  vec3(uPrecomputeLR[1][0], uPrecomputeLG[1][0], uPrecomputeLB[1][0]) +
        SH2n2(vNormal) * vPrecomputeLT[1][1] * SH2n2(vNormal) *  vec3(uPrecomputeLR[1][1], uPrecomputeLG[1][1], uPrecomputeLB[1][1]) +
        SH2n1(vNormal) * vPrecomputeLT[1][2] * SH2n1(vNormal) *  vec3(uPrecomputeLR[1][2], uPrecomputeLG[1][2], uPrecomputeLB[1][2]) +
        SH20(vNormal)  * vPrecomputeLT[2][0] * SH20(vNormal)  *  vec3(uPrecomputeLR[2][0], uPrecomputeLG[2][0], uPrecomputeLB[2][0]) +
        SH2p1(vNormal) * vPrecomputeLT[2][1] * SH2p1(vNormal) *  vec3(uPrecomputeLR[2][1], uPrecomputeLG[2][1], uPrecomputeLB[2][1]) +
        SH2p2(vNormal) * vPrecomputeLT[2][2] * SH2p2(vNormal) *  vec3(uPrecomputeLR[2][2], uPrecomputeLG[2][2], uPrecomputeLB[2][2]) 
        ;

    gl_FragColor = vec4(ret, 1.0);
}

void main(){
    vec3 ret = 
        SH00()         * vec3(uPrecomputeLR[0][0], uPrecomputeLG[0][0], uPrecomputeLB[0][0])  * SH00()         * vPrecomputeLT[0][0]+ 
        SH1n1(vNormal) * vec3(uPrecomputeLR[0][1], uPrecomputeLG[0][1], uPrecomputeLB[0][1])  * SH1n1(vNormal) * vPrecomputeLT[0][1]+ 
        SH10(vNormal)  * vec3(uPrecomputeLR[0][2], uPrecomputeLG[0][2], uPrecomputeLB[0][2])  * SH10(vNormal)  * vPrecomputeLT[0][2]+ 
        SH1p1(vNormal) * vec3(uPrecomputeLR[1][0], uPrecomputeLG[1][0], uPrecomputeLB[1][0])  * SH1p1(vNormal) * vPrecomputeLT[1][0] +

        SH2n2(vNormal) * vec3(uPrecomputeLR[1][1], uPrecomputeLG[1][1], uPrecomputeLB[1][1])  * SH2n2(vNormal) * vPrecomputeLT[1][1] +
        SH2n1(vNormal) * vec3(uPrecomputeLR[1][2], uPrecomputeLG[1][2], uPrecomputeLB[1][2])  * SH2n1(vNormal) * vPrecomputeLT[1][2] +
        SH20(vNormal)  * vec3(uPrecomputeLR[2][0], uPrecomputeLG[2][0], uPrecomputeLB[2][0])  * SH20(vNormal) * vPrecomputeLT[2][0] +
        SH2n1(vNormal) * vec3(uPrecomputeLR[2][1], uPrecomputeLG[2][1], uPrecomputeLB[2][1])  * SH2p1(vNormal) * vPrecomputeLT[2][1] +
        SH2p2(vNormal) * vec3(uPrecomputeLR[2][2], uPrecomputeLG[2][2], uPrecomputeLB[2][2])  * SH2p2(vNormal) * vPrecomputeLT[2][2]
        ;

    gl_FragColor = vec4(ret / 3.14, 1);
}