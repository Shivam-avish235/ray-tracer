# Real-Time OpenGL Path Tracer

![Project Screenshot](screenshot.png)
*(Place a screenshot of your render here named screenshot.png)*

## 🚀 About The Project

This is a hardware-accelerated **Path Tracer** written in **C++** and **OpenGL (GLSL)**.

The project is a GPU implementation based on the logic from **[Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)**.

Unlike traditional CPU ray tracers that take minutes to render a single frame, this application moves the heavy math to the GPU Fragment Shader. This allows it to run in **real-time**, letting you fly around the scene and adjust camera optics dynamically.

It features a custom **"Preview vs. Render"** workflow: navigate smoothly in a noisy preview mode, then lock the camera to resolve a high-quality, noise-free image instantly.

## ✨ Key Features

* **GPU Acceleration:** Runs entirely in a GLSL Fragment Shader for maximum parallelism.
* **Real-Time Path Tracing:** Calculates light bounces, shadows, and reflections at 60+ FPS.
* **Material System:**
    * **Lambertian:** Matte/Diffuse surfaces with accurate light scattering.
    * **Metal:** Reflective surfaces with adjustable fuzziness.
    * **Dielectric:** Glass surfaces with real refraction (Snell's Law) and Schlick's approximation.
* **Camera Optics:**
    * Adjustable **Focus Distance** (Focus on specific objects).
    * Adjustable **Defocus Angle** (Depth of Field / Bokeh effects).
* **Dynamic Sampling:**
    * **Preview Mode:** 1 sample per pixel (Fast, interactive).
    * **Render Mode:** Multi-sample accumulation (Smooth, converged image).

## 🛠️ Tech Stack

* **Language:** C++
* **Graphics API:** OpenGL 3.3 Core
* **Shader Language:** GLSL
* **Windowing & Input:** SDL2
* **Extension Loader:** GLAD

## 🎮 Controls

| Key | Action |
| :--- | :--- |
| **W, A, S, D** | Move Camera (Fly Mode) |
| **Mouse** | Look Around |
| **R** | **Toggle Render Mode** (Switch between Fast/Grainy and Slow/HQ) |
| **UP / DOWN** | Increase/Decrease Focus Distance |
| **LEFT / RIGHT** | Decrease/Increase Defocus Angle (Blur) |
| **O / L** | Increase/Decrease Ray Depth (Bounces) |
| **ESC** | Exit Application |

## 🔧 How It Works

1.  **Ray Generation:** For every pixel on the screen, the shader shoots a ray from the camera into the scene.
2.  **Intersection:** The ray is tested against all spheres in the scene using mathematical intersection formulas.
3.  **Scattering:** If a ray hits an object, it scatters based on the material properties (reflects off metal, refracts through glass, or bounces off matte).
4.  **Recursion:** This process repeats up to `MAX_DEPTH` times to simulate global illumination (light bouncing between objects).
5.  **Sampling:**
    * In **Preview**, only 1 random path is calculated per pixel to maintain high FPS.
    * In **Render (Pressed 'R')**, the loop runs 50-100 times per pixel in a single frame to average out the noise and produce a clean image.

## 📦 How to Build & Run

### Prerequisites (Linux)
You need a C++ compiler and the SDL2 development libraries.

```bash
sudo apt-get update
sudo apt-get install build-essential libsdl2-dev
