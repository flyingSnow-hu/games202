#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = min(1.0, uv.x + 0.01);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 albedo = GetGBufferDiffuse(uv);
  vec3 lightDir = normalize(wi);
  vec3 normal = normalize(GetGBufferNormalWorld(uv));
  float diff = max(dot(lightDir, normal), 0.0);
  return diff * albedo;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  return uLightRadiance * GetGBufferuShadow(uv);
}


#define MAX_DIST 5.0  // ??????????????????
#define STEP 0.1  // ??????
#define MIN_DIFF 0.2  // ????????????
#define SAMPLE_NUM 70

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  float dist = MAX_DIST;
  vec3 nDir = normalize(dir);
  for(float d = 0.0;d < MAX_DIST;d+=STEP)
  {
    hitPos = ori + nDir * d;
    float targetDepth = GetDepth(hitPos);
    vec2 screenUV = GetScreenCoordinate(hitPos);
    if(screenUV.x >= 0.0 && screenUV.x <= 1.0 && screenUV.y >= 0.0 && screenUV.y <= 1.0)
    {
      float screenDepth = GetGBufferDepth(screenUV);
      if(screenDepth < targetDepth) 
      {
        if (targetDepth - screenDepth < MIN_DIFF)
        {
          return true;
        }else
        {
          return false;
        }
      }
    }
  }

  return false;
}

void GetDirectRadiance(vec3 worldPos, out vec3 diffuse, out vec3 light)
{
  vec2 screenUV = GetScreenCoordinate(worldPos);
  diffuse = EvalDiffuse(uLightDir, uCameraPos-worldPos, screenUV);
  light = EvalDirectionalLight(screenUV);
}

void main() {
  float s = InitRand(gl_FragCoord.xy);
  vec3 worldPos = vPosWorld.xyz;
  vec3 normal = normalize(GetGBufferNormalWorld(GetScreenCoordinate(worldPos)));
  vec3 viewDir = normalize(uCameraPos-worldPos);
  vec2 screenUV = GetScreenCoordinate(worldPos);
  vec3 directDiffuse, directLight;
  GetDirectRadiance(worldPos, directDiffuse, directLight);

  vec3 indirect = vec3(0);
  vec3 tangent, bitangent;
  LocalBasis(normal, tangent, bitangent);
  tangent = normalize(tangent);
  bitangent = normalize(bitangent);
  mat3 tbn = mat3(tangent, bitangent, normal);
  vec3 ori = worldPos + normal * 0.05;  // ???????????????????????????
  for(int i = 0;i < SAMPLE_NUM;i++)
  {
    float pdf = INV_TWO_PI;
    vec3 localDir = SampleHemisphereCos(s, pdf);
    // vec3 localDir = SampleHemisphereUniform(s, pdf);
    vec3 sampleDir = tbn * localDir;
    vec3 hitPos;
    bool isHit = RayMarch(ori, sampleDir, hitPos);
    if (isHit)
    {      
      vec3 indirectDiffuse, indirectLight;
      GetDirectRadiance(hitPos, indirectDiffuse, indirectLight);
      vec3 bounceDiffuse = EvalDiffuse(normalize(hitPos - ori), vec3(0), screenUV);
      indirect += indirectDiffuse * indirectLight * bounceDiffuse / pdf;
    }
  }
  indirect = indirect / float(SAMPLE_NUM);

  vec3 linearColor =  indirect + directDiffuse * directLight;
  vec3 color = pow(clamp(linearColor, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(color.rgb, 1.0);
}
