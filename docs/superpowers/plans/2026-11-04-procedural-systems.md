# Procedural system prototype implementation plan

The starting galaxy has one fixed neighbor generated with a shared seed. Version 1 of the generator preserves that system across saves. Existing Astra flights and mines retain their original data. The first prototype adds a round trip from the station with one distinct planet and a second independently saved deposit.

- Verify the station route, reproducibility, landing area and separate deposit with a full-flight regression test.
- Add a versioned generator and pass its region parameters to the existing terrain, landing and mining logic.
- Add outbound and return jump actions, a local map, and a saved route flag. Keep legacy flight snapshots compatible.
- Verify both existing and new flight paths in Godot and export a signed Android APK.
