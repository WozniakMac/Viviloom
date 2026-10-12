# Character creator: completed work and remaining work

## Current checkpoint — 12 October 2026

The current implementation is saved in the `codex/character-creator` branch of the
managed `character-creator` worktree. This checkpoint finishes the native bob hair
pass. Work is paused at the user's request.

**The full Sims 4 character-creator quality target is not achieved.** Functional
checks pass, but they do not establish visual parity. The live Sims 4 reference has
more consistent facial styling, hair silhouettes, clothing and animation.

## Done

- [x] Separate native male and female Anny anatomy, using MakeHuman's original
  19,158 source vertex indices and UV layout before subdivision. The creator's
  body-frame buttons are labelled **Male** and **Female** and persist in saves.
- [x] Native toddler, child, teen, adult and elder deformations, with Young Adult
  as the base. Age changes the face and body geometry, bone rest positions,
  inverse binds, animation translation keys, fitted accessories and prop anchors.
  Physical height is separate from anatomical deformation.
- [x] All six ages are selectable. Full-body camera scale stays constant across
  ages so children visibly become shorter; face framing follows the age anatomy.
  Keeping the same age preserves lived days. Changing stage resets stage days.
  Elder gray hair is reversible display shading and preserves the saved color.
- [x] Female shoulder/arm fitting is narrower. Original restrained jaw, chin,
  cheek, nose and lip refinements accompany the native female head and skin.
  A fitted female tee replaces the bulky male sweater, with optional long sleeves.
  Initial Female selection uses Bob; subsequent frame switches remember customized
  hairstyles. These changes are a starting point for further feminine styling.
- [x] Native weight, muscle and combined weight/muscle body morphs. Clothing follows
  the same changes. Original cheek/jaw and hair responses accompany body settings
  while preserving the native eyes and the cut neck boundary.
- [x] Native fingers and thumbs, with thirty finger joints and preserved Anny skin
  weights. Palm/wrist fitting and skin material masks correct the missing thumb
  and wrist seam. Resting fingers have bounded, gently curled poses.
- [x] Runtime book, cup and fishing-rod grip profiles blend after body animation.
  Props attach relative to the native knuckle/wrist and follow frame and age changes.
  The cup has a rim, tapered body and liquid surface. Contacts are still authored
  profiles rather than a contact-solving system.
- [x] Fitted CC0 MakeHuman garments, jeans and shoes. Garment region separation
  preserves the correct texture on sweater hems and trousers. AI-generated plain
  blue fabric detail is used on the male sweater and female tee; denim retains its
  original CC0 atlas. Forearm and shin skin is opaque.
- [x] Seven selectable hairstyles. Short/tousled/bun/long use selected CC0 hair01
  assets, and ponytail uses the system pack. The current Bob uses the system
  pack's `bob01`, with an original smooth side sweep and restrained width. It
  replaces the compressed long-hair bob, exposes both eyes and reduces visible
  gaps and blunt card ends. A fitted scalp remains underneath.
- [x] Hair shading supports palette colors, strand detail and restrained anisotropic
  highlights. The earlier AI atlas supplement is used only on Long, whose UVs it
  was prototyped against; it is not applied to the new Bob.
- [x] Native eyes, textured eyebrows and eyelashes. Iris colors preserve pupils
  and whites. Native blink, smile, frown, angry-brow and sad-brow actions deform
  the face. An original inner-mouth surface closes the visible background gap.
- [x] Direct creator edits for nose width, jaw width, eye spacing, lip fullness,
  body weight and muscle. Face click/wheel zoom, background rotation, anatomical
  hover targets, gesture undo/redo, Escape cancellation and release over GUI work.
  Sliders and saves synchronize with drag edits; text-field undo remains separate.
- [x] Isolated creator lighting, a fading floor and a neutral editing idle.
  Forward+ skin uses restrained subsurface scattering; an opaque skin fallback
  exists for other renderers. Gameplay rendering layers are restored on exit.
- [x] Editable compressed Blender source and reproducible model generation.
  `sim.glb` is 104,400,504 bytes, below 100 MiB. The Bob's texture is exported as
  `assets/sim/bob01-diffuse.png` without recompression; its bytes match the original
  CC0 image. `tools/gltf_textures.py` updates buffer references when externalizing it.
- [x] AI visual concepts and texture prototypes are retained with their exact
  prompts/provenance. The latest strand-flow image and procedural solid-hair
  experiments were reviewed but not adopted into runtime hair: their silhouettes
  were worse than the fitted native asset. The generated image is retained as
  `assets/source/generated/hair-flow-prototype-ai.png`; local experimental code
  and renders are under ignored `output/hair-experiments/` and `output/`.

## Still to do

The following items remain part of the original goal, in suggested priority order.

1. **Female face and overall human styling.** Improve cheek/chin/eye/lid proportions,
   skin response and facial diversity against the live reference. The native female
   base now differs from the male, but it still needs a more coherent, appealing
   stylized appearance. Verify neutral and animated expressions as well as the
   smiling creator render; a flattering single image is insufficient.
2. **Age quality beyond the base anatomy.** Add age-specific skin detail and styling.
   Refine younger faces, lips and clothing, and interactions between age, expressions,
   weight, muscle and sculpt controls. Current editing deltas and skin atlases still
   start from adult data even though age anatomy and the skeleton change natively.
3. **Hair quality and choices.** Refine Bob's hairline, remaining fine cutout edges,
   side asymmetry and ends. Improve the other card-based styles, especially Short
   and Tousled. Add more original styles and verify all palette colors and ages.
4. **Torso and garments.** Further refine shoulder/armpit and sleeve joins, joint
   silhouettes, skirt fitting and clothing intersections through animation and
   body extremes. Add clothing variety and proportion controls for individual
   torso/limb regions rather than only global weight/muscle.
5. **Hand contact.** Improve thumb opposition, finger placement around each object,
   reading/reaching transitions and prop detail. Test visible palms and both hands
   in close view at every age and at body extremes. Current grips do not enforce
   physical contact constraints.
6. **Creator interaction depth.** Add nose profile, chin/cheek, eye/lid and individual
   limb controls, catalog thumbnails and broader undo history. Slider/catalog
   changes currently clear direct-gesture history. Improve small-window layouts
   where panels and editing controls crowd the model.
7. **Facial animation.** Add teeth, speech and fuller expression blending; verify
   eyelash/brow fitting and mouth interiors through combined expressions.
8. **Quality verification and cleanup.** Compare live Sims 4 and OpenSims through
   body extremes, age/frame changes, poses and lighting. Validate compatibility
   rendering as well as Forward+, and packaged exports. Investigate the existing
   test resource-cleanup/out-of-tree transform diagnostics. Model hot reload is
   not proven stable: a previous preview crashed during external asset reload.

## Latest verification

The final checks used the rebuilt model and its external Bob texture.

| Check | Result | Local log |
| --- | --- | --- |
| Native age anatomy, skeleton, inverse binds, poses, hair colors and saves | 3,566 checks, 0 failures | `output/native-bob-final-ages.log` |
| Real creator gestures, GUI routing, undo/cancel and saves | 146 checks, 0 failures | `output/native-bob-final-sculpt.log` |
| Frame identity, morphs, props, studio layers and saves | 0 failures | `output/native-bob-final-frames.log` |
| Head/hair body response, fixed eyes and neck joins | 0 failures | `output/native-bob-final-head-body.log` |
| Existing gameplay regression suite | TESTS PASSED, 0 failures | `output/native-bob-final-game-tests.log` |

The gameplay suite still emits existing transform/dependency/resource-cleanup
warnings and errors at shutdown. Its passing assertions do not mean the entire
log is clean. The focused age, frame, head/body and creator checks above pass.

Actual rendered evidence (local, ignored output files):

- Creator face and body: `output/native-bob-final-creator-face.png` and
  `output/native-bob-final-creator-body.png`.
- Both frames in front, three-quarter, side and back views:
  `output/native-bob-final-views.png` (`tools/preview_hair_views.tscn`).
- All six age faces: `output/native-bob-final-age-faces.png`
  (`tools/preview_ages.tscn`). Earlier full-body age comparison:
  `output/native-ages-final-body.png`.
- Hand/extreme/animation checks and renders from the previous completed hand pass:
  `output/hands-extremes-deformation.log`, `output/hands-runtime-check.log`,
  `output/hands-final.png` and `output/hands-female-heavy-fit.png`.

## Source files, licenses and rebuild

- Model source: `tools/model_source/character.blend`.
- Runtime model: `assets/sim/sim.glb`; external Bob texture:
  `assets/sim/bob01-diffuse.png`. Keep both runtime files together.
- Age rig: `assets/sim/age_rig.tres`, with readable `age-rig.json` source data.
- Anny: https://github.com/naver/anny — code Apache-2.0; generated graphical data
  CC0. Presets, metadata and licenses are under `assets/source/anny/`.
- MakeHuman system pack:
  https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html.
  Selected assets and declarations are under `assets/source/makehuman/system-assets/`.
  The full 280,737,770-byte archive was CRC checked (517 entries); provenance and
  SHA256 are in `assets/source/makehuman/pack-provenance.json`.
- Hair01 CC0 pack:
  https://static.makehumancommunity.org/assets/assetpacks/hair01.html. Selected
  entries were checked by ZIP CRC. Authors and provenance are retained in
  `assets/source/makehuman/hair01/provenance.json` and original asset declarations.
- AI concepts: `assets/references/`. Generated fabric/hair texture records:
  `assets/source/generated/`. Reference concepts are not in-game renders.

Only licensed graphical source assets and original work are incorporated. Sims 4
is a live visual/interaction reference; its meshes and textures are not used.

From the worktree, export presets using the isolated `.anny-venv` and
`tools/requirements-anny.txt`: `python tools/export_anny.py`. Then run
`blender --background --python tools/make_sim.py`. The model builder also regenerates
its external Bob texture. Import with `Godot --headless --path . --editor --import`.
Stop owned game previews before replacing/importing the model, then launch a fresh
preview. Anny caches and experimental outputs are intentionally not tracked.

Run renderer-dependent checks with a visible renderer, for example
`Godot --path . res://tools/check_ages.tscn` and
`Godot --path . res://tools/check_character_sculpt.tscn -- --scenario=skip_cas`.
Run gameplay tests with `Godot --headless --path . res://tests/run_tests.tscn`.
