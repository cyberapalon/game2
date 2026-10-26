# Asset provenance

The user selected original concept 1, Ash and Porcelain, for «Глубина».
Seven production source PNGs were generated with the built-in ChatGPT image
generator using that generated concept as the sole image reference. No stock
packs, external franchise artwork, external asset API, or paid asset service
was used. The reference concept is retained in assets/reference.

| Asset | Retained original | Integration |
| --- | --- | --- |
| Masked wanderer | assets/source/wanderer.png | 20 independently drawn poses, cropped and aligned into an RGBA atlas |
| Concrete, soil, roots and props | assets/source/terrain.png | Eight terrain tiles, eight decorative cutouts and a ledge derivative |
| Continuous ground | assets/source/ground.png | Full-width crop removes visible atlas repetition in the existing room |
| Distant ruined Earth | assets/backgrounds/skyline.png | Original opaque painted city and atmospheric root background |
| Near ruins and roots | assets/backgrounds/roots.png | Original transparent painted parallax layer |
| Foreground | assets/backgrounds/foreground.png | Original transparent painted bracken and roots |
| Dust, fog and ash | assets/source/effects.png | Cropped and aligned dust frames, fog and particle textures |
| Selected concept | assets/reference/ash_and_porcelain.png | Original AI concept chosen by the user, retained for art direction |
| Sound | assets/audio/*.wav | Original deterministic PCM synthesis in tools/build_sound_resources.py; no recordings or AI audio |
| Existing Roots rooms, NPC and entrances | world/roots/art/* | Preserved from main; prior provenance in docs/art-direction.md and docs/phase-3-report.md |
| HUD | ui/depth_hud.tscn | Native Godot controls and bundled fallback font |
| Engine and bundled components | Godot 4.6.3 | Retain applicable upstream notices when distributing |

The exact image prompts are retained in assets/GENERATION_PROMPTS.md. Input
and derivative checksums are in assets/generation_manifest.json. Mechanical
cropping, resizing, foot alignment and atlas packing use ImageMagick through
tools/build_art_resources.py; they do not generate replacement artwork.
Image generation itself is stochastic; retained inputs make extraction repeatable.

Legacy SVG assets and the former panorama remain as historical source files,
but are no longer referenced by the player or the surface terrain/backdrops.
The existing Roots rooms, NPC and entrance assets from main retain their
phase-three graphics; this revision preserves that route without adding gameplay.
Their previous
provenance is recorded in docs/phase-2-report.md and Git history.

This inventory does not assign a new repository license or assert exclusive
rights in generated imagery. Existing repository and engine notices remain
applicable. No music or commercial audio pack is included.
