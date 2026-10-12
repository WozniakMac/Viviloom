# Character creator quality work

Worktree: character-creator. Goal active; the full Sims 4 quality and interaction target is not yet achieved.

## Current character

- Native Anny 0.6.1 MakeHuman topology supplies the adult male anatomy, including the original fingers, thumbs, feet and face. All 19,158 source indices and UVs are retained before subdivision.
- Body weight and muscle sliders now use actual Anny heavy, fit and combined heavy/fit presets. A corrective morph keeps combined settings coherent. Fitted sweater, jeans and sneakers share those native variations.
- Hands retain a rigid wrist-to-palm transform; smooth arm masks prevent fingers receiving leg weights. All hand faces keep visible skin materials. The previous missing thumb was a clothing-mask defect.
- Shoulder coverage and neck binding corrected. Garment membership survives sleeve/leg cuts: connected sweater and trouser pieces get their own materials, including the sweater hem.
- CC0 MakeHuman casual outfit and shoes are fitted through their native barycentric bindings. Jeans preserve original seam/pocket/wear detail. Fabric shader preserves folds while supporting the game palette.
- Built-in imagegen edited the sweater UV texture into a plain blue crewneck. Source and prompt are retained in assets/source/generated; original source images remain intact. The generated texture is used only on the sweater.
- Short, tousled and bun styles use sculpted CC0 hair from the official hair01 pack; long, ponytail and bob use fitted system-pack assets. Short/tousled styles include a fitted scalp underneath. Hair shading has restrained highlights.
- Native eyes, softly blended textured eyebrows and eyelashes replace procedural overlays. Iris color preserves pupils and whites. Eyelashes follow the native blink morph.
- Native Anny blink, smile, frown, angry brow and sad brow actions deform the face; eyes remain fixed. Blinking runs in both CAS and gameplay.
- Persistent nose, jaw, eye spacing and lip controls retain legacy save defaults. A neutral creator idle keeps gameplay moods from changing posture while editing.
- Creator studio camera, key/fill/rim lighting and isolated rendering layers improve close inspection. Gameplay layers are restored on exit.
- Editable compressed Blender source: tools/model_source/character.blend. Image paths are relative. Runtime asset: assets/sim/sim.glb.

## Verification

- Focused hand binding and visible-material check: output/shoulder-hand-binding.log, 37,410 vertices, zero errors.
- Imported body/clothing native morph checks: output/garment-region-morphs.log, six meshes, zero failures.
- Native facial displacement, fixed eyeballs, save roundtrip and legacy defaults: output/anatomy-final-faces.log, zero failures.
- Game regression suite: output/anatomy-final-tests.log, TESTS PASSED (0 failures). Existing test cleanup/resource warnings still occur.
- Actual game renders inspect idle, walk, sitting, using, talking and lying poses; tools/preview_runtime.tscn uses Sim materials instead of raw GLB previews.
- Latest torso/creator: output/garment-region-torso.png and output/character-current.png. Hand closeup: output/final-palm.png. Soft face detail: output/soft-face-detail.png. Tests alone do not establish the visual quality target.

## Remaining goal work

- Native body/face diversity, gender and age anatomy; current age controls scale the adult male model.
- More clothing and hairstyle choices, skin variants and original styling; refine card-hair styles, the skirt and remaining joint silhouettes.
- Finger articulation for natural resting hands and gripping props; fingers currently follow the hand bone together.
- Direct face/body manipulation and catalog thumbnails; interface still relies on swatches and sliders.
- More complete facial animation, teeth, speech and expression blending.
- Live quality comparison with the Sims 4 reference across body extremes, animation, lighting and customizations.

## Sources and licenses

Anny: https://github.com/naver/anny. Code Apache-2.0, generated graphical data CC0. License and preset metadata are retained in assets/source/anny.

MakeHuman base and system pack: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html. Full 280,737,770-byte archive was CRC checked (517 entries); SHA256 b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107. Pack provenance is in assets/source/makehuman/pack-provenance.json. Only selected source assets are tracked; large archives and unused assets are ignored.

Official hair01 CC0 pack: https://static.makehumancommunity.org/assets/assetpacks/hair01.html. Selected entries retrieved by validated HTTP Range and ZIP CRC. Authors and provenance: assets/source/makehuman/hair01/provenance.json; original declarations remain in each .mhclo/.mhmat.

Graphical source assets are CC0. MakeHuman program source is not incorporated. Original AI concept and its prompt are in assets/references.

## Rebuild

Use an isolated .anny-venv with CPU torch and tools/requirements-anny.txt; run tools/export_anny.py, then Blender --background --python tools/make_sim.py from the worktree. Anny caches stay in .anny-cache. Run Godot --headless --path . --editor --import before the checks. Source/cache directories have .gdignore files.
