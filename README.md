# FluentMusic

> **iOS 26 Liquid Glass Edition** — Fast, fluid YouTube Music streaming built with Flutter, real shader-based Liquid Glass widgets, and Apple Music aesthetics.

[![Build & Release APK](https://github.com/ks3695602-sys/FluentMusic-Flutter/actions/workflows/build-apk.yml/badge.svg)](https://github.com/ks3695602-sys/FluentMusic-Flutter/actions/workflows/build-apk.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-red.svg)](LICENSE)
[![Liquid Glass Widgets](https://img.shields.io/badge/Liquid%20Glass-1.16.1-FA2D48.svg)](https://pub.dev/packages/liquid_glass_widgets)

---

## ✨ Features

- **Liquid Glass Navigation & Controls**: Authentic GPU shader refraction, specular highlights, and chromatic dispersion powered by `liquid_glass_widgets: ^1.16.1` (`GlassScaffold`, `GlassTabBar.bottom`, `GlassAppBar`, `GlassContainer.card`).
- **Apple Music Red Aesthetic**: Default `#FA2D48` accent color with OLED zinc-black canvas.
- **Word-by-Word Synced Lyrics**: Rich Apple Music style synced lyrics powered by `flutter_lyric` and `AppleMusicLyricUI`, featuring active line glows and instant tap-to-seek.
- **Instant Audio Extraction**: Pure Flutter & Dart audio engine backed by `just_audio` and YouTube Music stream extractors with zero playback delay.
- **Bespoke iOS 26 Launcher Icon**: Generated high-resolution squircle glass platter with specular rim lighting and neon music glyph.
- **Customizable Glass Pipeline**: Control shader quality tiers (Standard, Premium Impeller, Minimal) and blur intensity directly in Settings.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: Flutter (Dart >= 3.5.0)
- **Glass Engine**: `liquid_glass_widgets: ^1.16.1` (initialized at startup, shader pre-warming)
- **Lyrics Engine**: `flutter_lyric: ^2.0.2` with custom `AppleMusicLyricUI`
- **Audio & Media**: `audio_service`, `just_audio_media_kit`, YouTube stream extractors
- **Build System**: Classic Groovy Gradle (Android SDK 36, compileSdk 36, Java 17)

---

## 🚀 Building & Releases

Universal Release and Debug APKs are built automatically with 100% test passing via GitHub Actions:
- `FluentMusic-universal-release.apk`
- `FluentMusic-universal-debug.apk`

---

## 📄 License & Credits

FluentMusic is licensed under the **GNU General Public License v3.0**.
Based on the upstream open-source Musify core by Valeri Gokadze.
Liquid Glass toolkit developed by Pixel Innovations.
