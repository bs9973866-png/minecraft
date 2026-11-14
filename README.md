# BLOCKBOUND — Mobile Voxel Survival

BLOCKBOUND is an original, self-contained voxel sandbox game for Android, built with Godot Engine 4.7.2. It uses original procedural visuals and code; it does not include Minecraft assets or depend on the Minecraft client.

## Current playable foundation

- Procedural 3D voxel island with hills, beaches, caves, trees, water and underground ore deposits.
- First-person controller with mobile touch controls and desktop keyboard/mouse fallback.
- Survival and Creative modes, hotbar, block placing/mining, inventory and starter crafting recipes.
- Peaceful wandering wildlife and shy slimes that move away from the player.
- Local save/continue support.
- Android export preset and a GitHub Actions workflow for building an installable APK.

## Open in Godot

1. Install Godot **4.7.2 stable** (standard/GDScript build).
2. Import this repository folder as a Godot project.
3. Press **F6/F5** to run it on desktop, or configure Android export and export the `Android` preset.

The Android workflow can also be started from **GitHub → Actions → Build Android APK → Run workflow**. The APK is uploaded as a workflow artifact.

## Controls

**Touch:** left virtual joystick to move; drag the right side to look; on-screen buttons to jump, hit, mine, place and open inventory.

**Desktop:** WASD, mouse to look, Space to jump, left mouse to mine, right mouse to place, E for inventory, 1–8 to select hotbar slots, Esc to release the mouse.

## Project status

This is the first playable foundation, not a finished commercial-scale game. The world is finite for now, and the current mob AI, crafting tree and block set are intentionally small so the Android build stays lightweight. Expand the systems through the scripts in `scripts/`.

## License

Source code: MIT. All art and textures are generated procedurally by the project at runtime.