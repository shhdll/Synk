// Horizon gradient background (from uibrik's horizon-gradient), plain WebGL2.
(function () {
  const VERT = `#version 300 es
void main() {
  vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;

  const HEADER = `#version 300 es
precision highp float;

uniform vec2 u_res;
uniform float u_dpr;
uniform float u_time;
uniform float u_age;
uniform vec2 u_pointer;
uniform float u_pointerAmt;
uniform vec2 u_trail;
uniform vec3 u_colors[6];
uniform int u_count;
uniform float u_grain;
uniform float u_grainSize;

out vec4 outColor;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// 3D simplex noise by Ian McEwan, Ashima Arts, and Stefan Gustavson. MIT License.
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;
  i = mod289(i);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
  float n_ = 0.142857142857;
  vec3 ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);
  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

vec3 oklabToLinear(vec3 c) {
  float l = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
  float m = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
  float s = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
  l = l * l * l; m = m * m * m; s = s * s * s;
  return vec3(
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  );
}

vec3 linearToSrgb(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

float pointerDist(vec2 p, float trail) {
  vec2 a = u_pointer;
  vec2 b = mix(u_pointer, u_trail, trail);
  vec2 ab = b - a;
  float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
  return length(p - a - ab * h);
}
`;

  const SHADER = `
uniform float u_curve;
uniform float u_reach;
uniform float u_softness;
uniform float u_direction;
uniform float u_intro;
uniform float u_bulge;

vec3 stop(int i) {
  return u_colors[clamp(i, 0, u_count - 1)];
}

float spline(float a, float b, float c, float d, float s) {
  return 0.5 * (2.0 * b + (c - a) * s + (2.0 * a - 5.0 * b + 4.0 * c - d) * s * s + (3.0 * (b - c) + d - a) * s * s * s);
}

vec3 rampSmooth(float x) {
  float f = clamp(x, 0.0, 1.0) * float(u_count - 1);
  int i = min(int(floor(f)), u_count - 2);
  float s = f - float(i);
  vec3 a = stop(i - 1), b = stop(i), c = stop(i + 1), d = stop(i + 2);
  vec3 lab = vec3(spline(a.x, b.x, c.x, d.x, s), spline(a.y, b.y, c.y, d.y, s), spline(a.z, b.z, c.z, d.z, s));
  float chroma = max(spline(length(a.yz), length(b.yz), length(c.yz), length(d.yz), s), 0.0);
  float len = length(lab.yz);
  if (len > 1e-4) lab.yz *= chroma / len;
  lab.x = clamp(lab.x, 0.0, 1.0);
  return lab;
}

float outCubic(float x) {
  x = 1.0 - clamp(x, 0.0, 1.0);
  return 1.0 - x * x * x;
}

vec3 shade(vec2 frag) {
  float t = u_time * 0.1;
  float rise = outCubic(u_age / max(u_intro, 0.01));
  vec2 f = frag;
  vec2 res = u_res;
  if (u_direction > 2.5) {
    f = vec2(frag.y, u_res.x - frag.x);
    res = u_res.yx;
  } else if (u_direction > 1.5) {
    f = u_res - frag;
  } else if (u_direction > 0.5) {
    f = vec2(u_res.y - frag.y, frag.x);
    res = u_res.yx;
  }
  float aspect = res.x / res.y;
  vec2 p = vec2((f.x / res.x - 0.5) * aspect, 1.0 - f.y / res.y);
  float k = 1.66 * max(aspect / 1.6, 0.6) / max(u_curve * mix(0.6, 1.0, rise), 0.05);
  vec2 c = vec2(0.05 * sin(t * 0.7), -0.55 + 0.018 * sin(t * 1.1));
  float d = length(vec2((p.x - c.x) / k, p.y - c.y));
  d = mix(d, p.y - c.y, 0.55 * smoothstep(0.8, 1.35, d));
  d += 0.022 * snoise(vec3(p * 1.1, t * 0.6));
  d -= (u_reach - 1.0) * 0.25 - (1.0 - rise) * 1.1;
  if (u_bulge > 0.0) {
    float pd = pointerDist(frag, 0.5) / (0.32 * u_res.y);
    d -= u_bulge * u_pointerAmt * exp(-pd * pd);
  }
  float x = clamp((d - 0.66) / (0.7 * u_softness), 0.0, 1.0);
  x = mix(x, x * x * (3.0 - 2.0 * x), 0.5);
  return mix(oklabToLinear(u_colors[u_count - 1]), oklabToLinear(rampSmooth(x)), smoothstep(0.0, 0.6, u_age));
}
`;

  const FOOTER = `
void main() {
  vec3 c = linearToSrgb(shade(gl_FragCoord.xy));
  c += (hash12(floor(gl_FragCoord.xy / u_grainSize)) - 0.5) * u_grain;
  c += (hash12(gl_FragCoord.xy + 17.0) - 0.5) * (1.5 / 255.0);
  outColor = vec4(c, 1.0);
}
`;

  const toLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);

  function hexToOklab(hex) {
    let h = hex.trim().replace(/^#/, "");
    if (h.length === 3) h = [...h].map((c) => c + c).join("");
    const n = parseInt(h.slice(0, 6), 16);
    const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => toLinear(v / 255));
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ];
  }

  const STEPS = [
    [0.02, 0.05, 0.08],
    [0.22, 0.75, 0.05],
    [0.42, 1, 0],
    [0.62, 0.75, -0.04],
    [0.86, 0.3, -0.06],
    [0.995, 0.02, -0.08],
  ];

  const encode = (c) => {
    const v = c <= 0.0031308 ? c * 12.92 : 1.055 * c ** (1 / 2.4) - 0.055;
    return Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, "0");
  };

  function lchToHex(l, c, h) {
    for (let i = 0; i < 24; i++, c *= 0.9) {
      const a = c * Math.cos(h);
      const b = c * Math.sin(h);
      const L = (l + 0.3963377774 * a + 0.2158037573 * b) ** 3;
      const M = (l - 0.1055613458 * a - 0.0638541728 * b) ** 3;
      const S = (l - 0.0894841775 * a - 1.291485548 * b) ** 3;
      const rgb = [
        4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
        -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
        -0.0041960863 * L - 0.7034186147 * M + 1.707614701 * S,
      ];
      if (rgb.every((v) => v >= -0.001 && v <= 1.001) || i === 23) return `#${rgb.map(encode).join("")}`;
    }
    return "#000000";
  }

  function horizonShades(hex) {
    const [, a, b] = hexToOklab(hex);
    const c = Math.hypot(a, b);
    const h = Math.atan2(b, a);
    return STEPS.map(([l, k, dh]) => lchToHex(l, c * k, h + dh));
  }

  window.horizonGradient = function (box, o = {}) {
    const opt = { color: "#2b35d6", direction: "top", curve: 1, reach: 1, softness: 1.1, speed: 1, grain: 0.1, intro: 2.4, maxDpr: 1, ...o };
    const palette = opt.colors && opt.colors.length >= 2 ? opt.colors.slice(0, 6) : horizonShades(opt.color);

    // CSS stand-in until the first frame, and when WebGL2 isn't there
    const at = opt.direction === "bottom" ? "50% 140%" : "50% -40%";
    box.style.background = `radial-gradient(ellipse 140% 95% at ${at}, ${palette
      .map((c, i) => `${c} ${Math.round(58 + (i / (palette.length - 1)) * 42)}%`)
      .join(", ")})`;

    const cv = document.createElement("canvas");
    cv.setAttribute("aria-hidden", "true");
    const gl = cv.getContext("webgl2", { alpha: false, antialias: false, depth: false, stencil: false, powerPreference: "low-power" });
    if (!gl) return;

    const compile = (type, src) => {
      const s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error(gl.getShaderInfoLog(s));
        return null;
      }
      return s;
    };
    const vs = compile(gl.VERTEX_SHADER, VERT);
    const fs = compile(gl.FRAGMENT_SHADER, HEADER + SHADER + FOOTER);
    if (!vs || !fs) return;
    const program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.error(gl.getProgramInfoLog(program));
      return;
    }
    gl.useProgram(program);
    const loc = (name) => gl.getUniformLocation(program, name);

    const colors = new Float32Array(18);
    palette.forEach((c, i) => colors.set(hexToOklab(c), i * 3));
    gl.uniform3fv(loc("u_colors"), colors);
    gl.uniform1i(loc("u_count"), palette.length);
    gl.uniform1f(loc("u_grain"), opt.grain);
    gl.uniform1f(loc("u_direction"), opt.direction === "bottom" ? 2 : 0);
    gl.uniform1f(loc("u_curve"), opt.curve);
    gl.uniform1f(loc("u_reach"), opt.reach);
    gl.uniform1f(loc("u_softness"), opt.softness);
    gl.uniform1f(loc("u_intro"), opt.intro);
    gl.uniform1f(loc("u_bulge"), 0);

    box.prepend(cv);
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
    let time = 12;
    let age = 0;
    let last = 0;
    let raf = 0;

    const resize = () => {
      const r = box.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, opt.maxDpr);
      cv.width = Math.max(1, Math.round(r.width * dpr));
      cv.height = Math.max(1, Math.round(r.height * dpr));
      gl.viewport(0, 0, cv.width, cv.height);
      gl.uniform2f(loc("u_res"), cv.width, cv.height);
      gl.uniform1f(loc("u_grainSize"), Math.max(1, cv.width / r.width));
    };

    const render = () => {
      gl.uniform1f(loc("u_time"), time);
      gl.uniform1f(loc("u_age"), reduce.matches ? 1e4 : age);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    };

    const tick = (now) => {
      raf = 0;
      const dt = last ? Math.min((now - last) / 1000, 0.1) : 0;
      last = now;
      time += dt * opt.speed;
      age += dt;
      render();
      if (!reduce.matches && !document.hidden) raf = requestAnimationFrame(tick);
    };

    const start = () => {
      last = 0;
      if (!raf) raf = requestAnimationFrame(tick);
    };

    new ResizeObserver(() => {
      resize();
      render();
    }).observe(box);
    document.addEventListener("visibilitychange", start);
    reduce.addEventListener("change", start);
    resize();
    render();
    // the canvas is drawing now, so the CSS stand-in isn't needed under it
    box.style.background = "none";
    start();
  };
})();
