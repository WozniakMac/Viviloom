# Character creator quality work

Worktree: character-creator. The full Sims 4 quality and interaction target is not yet achieved.

## Current character

- Native Anny 0.6.1 MakeHuman topology supplies separate adult male and female anatomy, including the original fingers, thumbs, feet and face. All 19,158 source indices and UVs are retained before subdivision.
- Body weight and muscle sliders now use actual Anny heavy, fit and combined heavy/fit presets. A corrective morph keeps combined settings coherent. Fitted sweater, jeans and sneakers share those native variations.
- Hands retain a rigid wrist-to-palm transform; smooth arm masks prevent fingers receiving leg weights. Native Anny finger weights survive subdivision and cuts. Thirty finger joints provide independent deformation and a gently curled resting pose on both frames; talking and waving relax the fingers further. All hand faces keep visible skin materials. The previous missing thumb was a clothing-mask defect.
- A Godot skeleton modifier blends right-hand book, cup and fishing-rod grips after body animation. Objects are anchored from the native middle knuckle and rotate with the wrist. Grip changes and release blend smoothly, including after switching frames. The cup has a tapered round mesh, rim and liquid surface.
- Exposed forearm and shin skin now uses opaque rendering; this removes the material seam around the wrist caused by visible skin using transparency.
- Shoulder coverage and neck binding corrected. Garment membership survives sleeve/leg cuts: connected sweater and trouser pieces get their own materials, including the sweater hem.
- CC0 MakeHuman casual outfit and shoes are fitted through their native barycentric bindings. Jeans preserve original seam/pocket/wear detail. Fabric shader preserves folds while supporting the game palette.
- Built-in imagegen edited the sweater UV texture into a plain blue crewneck. Source and prompt are retained in assets/source/generated; original source images remain intact. The generated texture is used only on the sweater.
- Short, tousled and bun styles use sculpted CC0 hair from the official hair01 pack; long uses sculpted culturalibre_hair_01 from hair01, bob is an original chin-length restyle of those locks, and ponytail uses a fitted system-pack asset. Short/tousled/long/bob styles include a fitted scalp underneath. The bob has narrower, shorter ends. Hair shading has restrained anisotropic highlights, softer normal detail and dark-texture tone compression to preserve strands. AI clump luminance supplements the original Long/Bob atlas without changing its alpha mask; exact UV island matching was not achieved by imagegen. Asset and exact prompt provenance are in assets/source/generated/provenance.json.
- Female base uses its own native facial proportions and CC0 female skin, plus restrained jaw/chin/nose/lip refinement applied consistently to the base and every action. Male/Female controls switch the actual model and persist through saving.
- Native eyes, softly blended textured eyebrows and eyelashes replace procedural overlays. Iris color preserves pupils and whites. Eyelashes follow the native blink morph.
- Native Anny blink, smile, frown, angry brow and sad brow actions deform the face; eyes remain fixed. Blinking runs in both CAS and gameplay.
- Persistent nose, jaw, eye spacing and lip controls retain legacy save defaults. A neutral creator idle keeps gameplay moods from changing posture while editing.
- Creator studio camera, softer key/fill/rim lighting, a fading floor without a hard horizon and isolated rendering layers improve close inspection. Native skin uses restrained subsurface scattering in Forward+, with normal opaque skin fallback in other renderers. Gameplay layers are restored on exit.
- Editable compressed Blender source: tools/model_source/character.blend. Image paths are relative. Runtime asset: assets/sim/sim.glb.

## Verification

- Focused hand binding and visible-material check: output/shoulder-hand-binding.log, 37,410 vertices, zero errors.
- Imported body/clothing native morph checks: output/garment-region-morphs.log, six meshes, zero failures.
- Native facial displacement, fixed eyeballs, save roundtrip and legacy defaults: output/anatomy-final-faces.log, zero failures.
- Game regression suite: output/anatomy-final-tests.log, TESTS PASSED (0 failures). Existing test cleanup/resource warnings still occur.
- Actual game renders inspect idle, walk, sitting, using, talking and lying poses; tools/preview_runtime.tscn uses Sim materials instead of raw GLB previews.
- Both-frame frame switching/identity, props, studio layers and save checks: output/female-final-frame-check.log, zero failures. Native face and clothing checks: output/female-final-face-check.log and output/female-final-morph-check.log, zero failures. Hand binding: output/female-final-binding.log, 37,344 female and 37,410 male vertices, zero errors. Game suite: output/female-final-tests.log, TESTS PASSED (0 failures), with existing out-of-tree transform and resource-cleanup diagnostics.
- Female AI concept and exact prompt: assets/references/female-character-concept.png and female-character-concept.prompt.txt, generated with built-in imagegen; design reference, not an in-game render.
- Current female game views: output/female-final-face.png, output/female-final-body.png; body extremes: output/female-final-heavy.png and output/female-final-fit.png; animation poses and hairstyles: output/female-final-poses.png and output/female-final-hair.png.
- Native finger deformation across both frames and base/heavy/fit/combined extremes: output/hands-extremes-deformation.log, 80 independent digit checks, zero failures. No unrelated anatomy moves. Native hand binding: output/fingers-binding-check.log, zero errors.
- Real Godot AnimationMixer/modifier ordering, grip changes, wrist-relative props, release and rebuilt skeletons: output/hands-runtime-check.log, zero failures. Frame identity/save, face and body/clothing morph checks: output/hands-frame-check.log, output/hands-face-check.log and output/hands-morph-check.log, zero failures. Game suite: output/hands-game-tests.log, TESTS PASSED (0 failures); existing transform/cleanup diagnostics remain.
- Latest game hand renders: output/hands-final.png, output/hands-female-heavy-fit.png and output/hands-final-cas-palm.png. Female creator after the hand pass: output/hands-final-female-body.png. Visual inspection confirms the wrist seam is removed and the finger bends remain bounded; authored prop contact still needs refinement.
- Latest torso/creator: output/garment-region-torso.png and output/character-current.png. Hand closeup: output/final-palm.png. Soft face detail: output/soft-face-detail.png. Tests alone do not establish the visual quality target.

- Female hair/studio checkpoint: output/beauty-studio-final-face.png and output/beauty-studio-final-body.png show the actual game creator. Brown/blonde material comparison: output/beauty-hair-comparison-v2.png, built by tools/preview_portraits.tscn. Both native hand bindings, frame/save/prop switches, face morphs, body/clothing morphs and hand modifier checks all pass in output/beauty-hair-*-check.log. Game suite: output/beauty-hair-game-tests.log, TESTS PASSED (0 failures), with existing transform/resource cleanup diagnostics.
- Live Sims 4 comparison inspected the existing female household in CAS at full body and face zoom. Reference hair uses broad coherent locks, controlled strand highlights and soft silhouette ends; face lighting gives more cheek/nose depth. Current OpenSims card edges and silhouette remain below that target. The compatibility renderer loads successfully but still differs visibly in brightness/material response; Forward+ is the current visual target.

## Remaining goal work

- Native age anatomy and further face diversity; current age controls still scale the selected adult model.
- More clothing and hairstyle choices, skin variants and original styling; refine card-hair styles, the skirt and remaining joint silhouettes.
- Further hand contact refinement: thumb opposition, object-specific finger placement, grip transitions during reaching and reading, and prop detail. Current grips use authored profiles rather than contact constraints.
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
