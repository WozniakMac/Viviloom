# OpenSims

An original life-simulation sandbox built with Godot 4.7.

- Open `project.godot` in Godot 4.7.2 and press F5, or run `Godot_v4.7.2-stable_win64.exe --path .`
- Tests: `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/run_tests.tscn`
- Screenshot smoke run: `... --path . -- --screenshot=C:/path/out.png --scenario=<menu|mood|cas|build|sleep>`
- Skip Create a Sim at start: `... --path . -- --scenario=skip_cas`

The game starts in Create a Sim (name, look, up to three traits), then moves the Sim
into the starter house. The interface follows the layout of classic life sims: portrait,
mood and moodlets bottom-left, time controls bottom-centre, needs / skills / simology
bottom-right, mode buttons and notifications top-right.

Controls: left-click to walk or open an object's pie menu, click a queued action to
cancel it, P / 1-3 for speed, F3 build, F1 live, V walls, WASD/arrows to pan, Q/E or
middle-drag to rotate, wheel to zoom.
