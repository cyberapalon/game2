# Asset provenance

Ash and Porcelain is the original direction selected by the user for «Глубина».
All active game artwork uses original AI-generated PNG sources. No stock pack,
external franchise artwork, paid asset service, or separate generation API is used.
The only image reference is the retained original selected concept.

## Current route cohesion pass

Eight new source images were made with the built-in ChatGPT image generator.
Original bytes are retained in assets/source/route. The exact prompts are in
assets/ROUTE_GENERATION_PROMPTS.md; source and derivative SHA-256, dimensions
and byte counts are in assets/route_generation_manifest.json.

| Artwork | Retained source | Runtime use |
| --- | --- | --- |
| Stable traveler parts | hero_parts.png | Nine painted cutouts; one immutable mask/torso; articulated gait |
| Watcher, shaft, passages, platform, keepsake and plants | route_props.png | Inspected cutouts with matching ground baselines |
| Roots soil | roots_soil.png | One continuous full-width terrain crop |
| Near root overlay | roots_near.png | Separate transparent parallax layer |
| Landing | landing_depth.png | Original distant mine/root chamber |
| Junction | junction_depth.png | Original branching root vault |
| Hollow | hollow_depth.png | Original secret hollow background |
| Seal | seal_depth.png | Original deep root chamber background |

The foreground reuses the earlier original painted surface foreground; its
source digest and the selected concept digest are included in the new manifest.
Preparation uses ImageMagick through tools/build_route_art.py: mechanical
cropping, resizing, alpha-aware placement and metadata stripping on derivatives.
No character, terrain or scenery is replaced with programmatically drawn art.
The original source images and their generation metadata remain intact.

The articulated animation transforms these raster paintings in Godot. Mask and
torso never switch images or scale. Inverse kinematics solves the drawn legs;
there are no geometric placeholder limbs or generated intermediate drawings.

## Retained first surface pass

Original panorama, near roots, props, continuous surface ground, dust, mist and
ash remain from the first AI pass. Sources and exact prompts are retained in
assets/source, assets/backgrounds, assets/GENERATION_PROMPTS.md and
assets/generation_manifest.json. The old independently generated character
atlas remains historical and is not referenced by the active player scene.
The selected original concept is assets/reference/ash_and_porcelain.png.

Legacy SVG assets remain historical source files. Active room/player scenes do
not reference them, and the release inspector rejects any SVG resource in PCK.
Historical generators are guarded against restoring the former SVG pass.

## Audio and bundled components

Sound files in assets/audio are original deterministic PCM synthesis recipes
from tools/build_sound_resources.py, not recordings or AI music. HUD uses native
Godot controls and its bundled fallback font. Godot 4.6.3 and bundled components
retain their upstream notices. No runtime dependencies have been added or updated.

This inventory does not assign a new repository license or assert exclusive
rights in generated imagery. Retained source images make extraction repeatable;
image generation itself is stochastic and is not claimed reproducible.
