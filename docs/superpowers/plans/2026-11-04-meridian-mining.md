# Meridian mining implementation plan

> Use inline execution and verify each phase against the existing Godot project.

**Goal:** Ship the first survey, mining, haul and sale loop for Android.

**Architecture:** A saved mining model advances elapsed time independently of surface flight. Surface actions and mining visuals use the existing planet scene, controls, navigation and checkpoint format. Cargo transfers use the existing ore and capacity.

**Tech stack:** Godot 4.5.1, GDScript, Android arm64.

**Spec:** docs/superpowers/specs/2026-11-04-meridian-mining-design.md

- [x] Write and run the mining tests against 0.9.0. Cover production, limits, offline event order, replay, old saves, UI action gates, partial transfer, write failure and sale.
- [x] Add mining state and offline simulation. Persist setup and unload atomically with cargo and reconcile at startup and application resume.
- [x] Connect survey and landed actions to the planet scene. Mark signal and surveyed sites on the map and navigation, and fit controls in both orientations.
- [x] Run all existing and new tests. Export the APK with the previous test key, verify package, version, signatures and Android ABI, then package source and history.
