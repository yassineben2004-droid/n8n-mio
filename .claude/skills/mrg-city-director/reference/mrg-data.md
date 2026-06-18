# MRG City — Reference Data

Data file for the `mrg-city-director` skill. Read this before writing map/character/asset code so you use the real names, layout, and paths instead of inventing them.

---

## Characters (12 — "il blocco" / MRG)

Default player: **sugo**.

| id      | name    | 3D model (GLB) | notes |
|---------|---------|----------------|-------|
| sugo    | Sugo    | ✅ exists       | default player character |
| huncho  | Huncho  | ✅ exists       | second finished model |
| behope  | Behope  | ❌ to generate  | |
| chakour | Chakour | ❌ to generate  | |
| amuna   | Amuna   | ❌ to generate  | |
| peco    | Peco    | ❌ to generate  | |
| zable   | Zable   | ❌ to generate  | |
| yzilow  | Yzilow  | ❌ to generate  | |
| mimmo   | Mimmo   | ❌ to generate  | |
| lucas   | Lucas   | ❌ to generate  | |
| anas    | Anas    | ❌ to generate  | |
| sdoink  | Sdoink  | ❌ to generate  | |

Generate the remaining 10 models ONLY after Sugo + Huncho look correct in-engine (Phase 5). Each cutout image → image-to-3D (textured). Reuse, don't recreate.

Special NPCs to port from the old prototype later:
- **Hamza Dangerous** — chaser NPC, line: "Ehi ragazzo, fermati! Hai un 5?"
- **Yasso Elmani** — NPC.
- **Mario** — bar owner (Caffè Molinari).

---

## Setting

Fictionalized **Muraglia**, San Fereolo quarter, Lodi (Italy). Real spine streets: **viale Pavia** and **via Colombo**. Night-time mood. Compress the real area: keep landmarks, cut filler, keep it walkable.

## Locations (9 real night photos available as textures)

| key       | place |
|-----------|-------|
| muraglia  | La Muraglia (long apartment block — the icon of the neighborhood) |
| bar       | Caffè Molinari |
| casaquart | Casa del Quartiere |
| sottoponte| Il Sottoponte |
| garage    | Il Garage |
| garageint | Garage interior |
| centro    | Centro |
| parco     | Parco Martiri |
| campetto  | Il Campetto (football cage) |

## Reference map layout (from the prototype — meters, x = east/west, z = north/south)

Use as a starting blueprint for the compressed city; adjust for gameplay density.

- **viale Pavia**: main road, runs east-west at z = 0, width ~9.
- **strada bassa**: parallel road at z = 52, width ~8.
- **via Colombo**: north-south road at x = 0, width ~8. Side roads at x = -80 and x = +80.
- **La Muraglia**: two long blocks at (x -52, z -14) and (x 58, z -14), ~100 and ~88 long, tall.
- **Caffè Molinari**: (x -100, z 5).
- **Casa del Quartiere**: (x 96, z 5).
- **Sottoponte**: (x -52, z 56).
- **Garage**: (x 62, z 56).
- **Centro**: (x 96, z 56).
- **Parco Martiri**: (x -30, z -36).
- **Il Campetto**: (x 52, z -34), with fence.

Zones for on-screen "you are entering" labels: LA MURAGLIA, CAFFÈ MOLINARI, CASA DEL QUARTIERE, PARCO MARTIRI, IL CAMPETTO, IL SOTTOPONTE, IL GARAGE, VIALE PAVIA.

---

## Suggested Godot asset paths

```
res://characters/<id>.glb          # 3D models (sugo, huncho first)
res://characters/portraits/<id>.png # cutout images / select-screen portraits
res://locations/<key>.webp          # location photos (textures / references)
res://scenes/player.tscn
res://scenes/main.tscn
res://scenes/vehicles/car.tscn
res://scripts/player.gd
res://scripts/chase_camera.gd
```

## Gameplay carried over from the prototype (target features)

- Third-person chase camera (script-driven, see skill rule 6).
- Move (WASD / joystick), run (Shift), punch (melee), enter/exit vehicle, talk to NPC.
- Wanted system (stars), cash, health.
- Drivable cars (arcade handling).
- NPCs L1 (walk/idle/react) → L2 (flee/fight when punched).
- Minimap.

## Known failure modes already solved (don't repeat)

- Character renders as a dark "blob"/Pac-Man → unlit PBR under night lighting + wrong scale, NOT a load failure. Light the scene or use unlit materials; auto-scale by AABB.
- "Nothing moves / no output" → unsaved file, no Main Scene set, or script not attached. Check those three first.
- Camera looks top-down/empty → spawn the player next to a landmark (the Muraglia) and drive the camera from script with look_at.
