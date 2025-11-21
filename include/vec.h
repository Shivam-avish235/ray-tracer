#pragma once
#include <cmath>

struct vec3 {
    float x, y, z;
    vec3() : x(0), y(0), z(0) {}
    vec3(float X, float Y, float Z) : x(X), y(Y), z(Z) {}

    vec3 operator+(const vec3& v) const { return vec3(x + v.x, y + v.y, z + v.z); }
    vec3 operator-(const vec3& v) const { return vec3(x - v.x, y - v.y, z - v.z); }
    vec3 operator*(float s) const { return vec3(x * s, y * s, z * s); }
    vec3 operator/(float s) const { return vec3(x / s, y / s, z / s); }

    vec3& operator+=(const vec3& v) { x += v.x; y += v.y; z += v.z; return *this; }
    vec3& operator-=(const vec3& v) { x -= v.x; y -= v.y; z -= v.z; return *this; }
    vec3& operator*=(float s) { x *= s; y *= s; z *= s; return *this; }
};

// float * vec3
inline vec3 operator*(float s, const vec3& v) { return vec3(v.x * s, v.y * s, v.z * s); }

inline float dot(const vec3& a, const vec3& b) { return a.x*b.x + a.y*b.y + a.z*b.z; }

inline vec3 cross(const vec3& a, const vec3& b) {
    return vec3(
        a.y*b.z - a.z*b.y,
        a.z*b.x - a.x*b.z,
        a.x*b.y - a.y*b.x
    );
}

inline float length(const vec3& v) { return std::sqrt(dot(v, v)); }

inline vec3 normalize(const vec3& v) {
    float len = length(v);
    if (len == 0.0f) return vec3(0,0,0);
    return v / len;
}
