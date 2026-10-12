# Reference play-session notes

Observations from playing the reference life-sim (The Sims 4) in a window, used to decide
which mechanics OpenSims should have. Only mechanics and layout ideas are taken; all
names, art and text in OpenSims are original.

## Flow
1. Main menu → **New Game** → Create-a-Sim.
2. **Create-a-Sim**: name, age/gender, one *aspiration* (grouped by category: knowledge,
   creativity, fortune, love, family, food, athletic...), up to three *traits* in tabs
   (emotional, hobby, lifestyle, social). Conflicting traits grey out (Cheerful ↔ Gloomy).
   Picking traits changes the idle animation right away. Clicking a body part opens a
   ring of clothing categories and a grid of swatches; changes apply instantly.
3. Household is saved, then **world select** → neighbourhood map. Empty / for-sale lots
   are outlined in green; hovering shows name, size (e.g. 20×15), beds/baths and price.
   Starting funds are 20,000; moving into a furnished house deducts its price.

## Live mode
- Camera: WASD / drag to pan, right-drag to rotate, wheel or Z/X to zoom. Walls are cut
  away around the visible rooms.
- **Bottom-left**: portrait with a vertical mood label coloured by emotion
  ("Fine" green, "Inspired" teal...), moodlet icons beneath it, *wants* in thought
  bubbles above, household funds below, action queue as a column of icons beside it.
- Hovering a moodlet: emotion and weight ("Inspired +1"), name ("Inspired by
  literature"), source activity ("Browsing books"), flavour text and time left ("2 hours").
- **Bottom-right**: panel tabs – aspiration, career, skills, relationships, inventory,
  needs, traits ("Simology"). Needs are 6 bars in two columns (Bladder, Fun / Hunger,
  Social / Energy, Hygiene) with arrows showing the direction of change.
- Clicking an object opens a ring of pill-shaped labels around the cursor (bed: Sleep,
  Nap, Relax, Sit, Assign bed, Upgrade). Clicking the floor gives "Go here".
- Speed controls bottom-centre: pause / 1 / 2 / 3 with the clock under them.
- Sims act autonomously right after moving in (sat down, read books, watched TV), and
  pick up moodlets from those activities that change their mood.

## Build / Buy (F2)
- Lot grid shown, catalogue bottom-left browsable *by room* (a clickable illustrated
  room) or by function; items appear in a strip of thumbnails.
- Item tooltip: name, price, description and stats (e.g. fridge: food quality,
  energy efficiency, unreliability, +cooking skill).

## What OpenSims implements from this
- Steps 1–4: lot, click-to-walk, six needs, objects with pie menus, action queue, speed
  controls, autonomy. Build mode with walls, doors, catalogue, funds.
- Step 5: emotions from moodlets (with intensities), need moodlets, traits (lasting and
  recurring moodlets, skill and decay modifiers, favourite activities), skills 0–10
  boosted by the matching emotion, paintings that earn money, a portrait card with mood
  plate and moodlet tooltips, needs/skills/traits tabs, and a plumbob over the Sim.
- Step 6: Create a Sim (studio backdrop, hexagon trait slots with conflicts, colour
  swatches, rotate, green tick) and a UI pass to match the reference layout and style:
  light blue-white panels, live circular portrait with a vertical mood plate, round
  moodlets and queue icons with progress rings, speed pill with clock, icon tab bar for
  Needs / Skills / Simology with trend arrows on need bars, white pill pie menu,
  notification cards, and a build catalogue with rendered thumbnails and stat tooltips.
- Step 7: socials (two-level pie menu Friendly / Romance / Mean), friendship and romance
  with level names, rejections and jokes that fall flat, a visiting neighbour, and a
  Relationships tab.
- Step 8: careers with five levels, Mon–Fri shifts, leaving the lot, pay, performance
  from mood and skill, promotions, and a Career tab.
- Step 9: aspirations with milestones (chosen in Create a Sim), wants as thought bubbles
  above the portrait, satisfaction points, and an Aspiration tab.
- Step 10: neighbourhood map after Create a Sim: lots for sale outlined in green, hover
  cards with size, rooms and price, and a moving truck to buy and move in.
- Steps 11-20: day and night with lamps, title screen and save/load, a rigged and animated
  character model (Blender), households and switching Sims, modelled furniture, bills,
  windows/paint/floors, generated sound and music, speech/thought bubbles, life stages,
  school and babies.
- Steps 21-30: townies, the phone and community lots, roofs and a street of neighbours,
  dishes/accidents/passing out, five more skills, breakdowns and fires, event dialogs,
  body sliders and outfit cuts, emotional interactions and the Rewards Store, pools, and a
  second storey with stairs.
- Steps 31-44: marriage and moving in, pizza delivery, gym/library/lounge, picture icons,
  outfit categories with the change spin, hover highlights, stereo and dancing, carpool,
  more careers with work styles, fourteen traits, death and the Grim Reaper, furniture
  colour swatches, mood body language, inventory and paintings to hang, recipes and group
  meals, homework and toys, and Manage Households.
