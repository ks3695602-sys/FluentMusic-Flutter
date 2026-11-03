# FluentMusic

<div align="center">

![FluentMusic Banner](assets/images/cover.jpg)

**Modern, High-Fidelity Music Streaming & Offline Player with Liquid Glass Visuals**

[![Build & Release APK](https://github.com/ks3695602-sys/FluentMusic-Flutter/actions/workflows/build-apk.yml/badge.svg)](https://github.com/ks3695602-sys/FluentMusic-Flutter/actions/workflows/build-apk.yml)
[![Version](https://img.shields.io/badge/version-v1.0.9--flutter-blue.svg)](https://github.com/ks3695602-sys/FluentMusic-Flutter/releases)
[![Platform](https://img.shields.io/badge/platform-Android-green.svg)](https://github.com/ks3695602-sys/FluentMusic-Flutter)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

</div>

---

## ✨ Features

### 💎 Liquid Glass Engine
- **GPU Accelerated Shaders**: High-performance fragment shaders rendering real-time light refraction, chromatic aberration at the edges, and specular reflections.
- **Directional & Progressive Blur**: Zero-lag backdrop filters with customizable intensity and tinting.
- **Dynamic Mesh Canvas**: Fluid, animated 4-point color mesh background that extracts and animates real-time hues from the currently playing album artwork.
- **Live Liquid Glass Studio**: Fine-tune blur intensity, refractive index, glass tint opacity, and optical prism effects in real time.

### 🎧 Dual-Home Experience
- **Tab 1: Home (Personalized)**: Taste-driven dynamic recommendations, Quick Picks, Smart Mixes, Forgotten Favorites, and Chill Radio.
- **Tab 2: New Releases**: Dedicated discovery radar featuring Global Top 50 Charts, Fresh Weekly Drops, Viral Hits, and Genre Explorer.

### 🎵 High-Fidelity Audio
- **Stream Bitrate**: Seamless playback of high-bitrate audio streams (up to 160kbps Opus and 256kbps AAC).
- **Background Playback**: Persistent foreground media notification with seekable scrub bar, lockscreen controls, and system media buttons.
- **Device Music**: Integrated device storage scanner to seamlessly organize and play your local MP3, FLAC, and AAC files.

### 🎤 Word-by-Word Synced Karaoke Lyrics
- Live real-time synchronized lyrics with animated syllable highlighting.
- Tap any lyric line to jump and seek directly to that exact point in the song.
- Multi-source fallback engine for accurate lyric matching across languages and genres.

### 🚀 Continuous Updates
- In-app update checker integrated directly with GitHub Releases.
- Consistent keystore signing for smooth over-the-air updates without package signature conflicts.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter 3.29+ / Dart 3.2+
- **State Management**: `flutter_riverpod`
- **Audio Pipeline**: `just_audio` + `audio_service` + `audio_session`
- **Innertube & Metadata**: `youtube_explode_dart`
- **Local Scanner**: `on_audio_query`
- **Visuals & Shaders**: `liquid_glass_widgets` + `inspire_blur` + `mesh_gradient` + custom GLSL fragment shaders

---

## 📦 Building from Source

### Prerequisites
- Flutter SDK 3.24+ or 3.29+
- Android SDK (API 35, Build Tools 35.0.0)
- Java 17+

### Steps
```bash
# Clone the repository
git clone https://github.com/ks3695602-sys/FluentMusic-Flutter.git
cd FluentMusic-Flutter

# Fetch dependencies
flutter pub get

# Build Universal Release APK
flutter build apk --release

# Built APK will be available at:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 📄 License
This project is licensed under the MIT License.
