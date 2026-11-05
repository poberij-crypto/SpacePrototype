# Stars, planetary systems and corner HUD

The user requests a central star and several planets in each existing system, alongside the previously agreed corner HUD. Version 0.12.0 will show a central star and three planets per system, with a map listing and selection of orbital destinations. Existing Astra and Terra Nova landing regions remain the landable destinations for this step. Their positions, terrain seeds and mining state stay compatible with earlier checkpoints. New bodies have distinct visual properties and orbital approach points. Galaxy/story expansion remains a later step.

- Add a deterministic orbital catalog in world_generator.gd without changing the existing neighbor descriptor or generation version.
- Draw stars, coronas and three planets in both space roots, and extend camera clipping distance. Keep atmosphere, station and target visibility consistent across scene changes.
- Extend the system map with orbit paths, star and planets, selection and a navigation action. Preserve surface maps and station selection.
- Move persistent HUD controls and readouts into the four corners using available viewport space, preserve central aim/navigation/context actions, and reset touches on orientation change.
- Verify orbital catalog, navigation, old mission/surface paths and corner HUD in Godot, build and sign APK, and publish source changes to the feature branch.
