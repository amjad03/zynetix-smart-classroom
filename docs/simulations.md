# Simulations and activities: the authoring guide

Every topic of every subject can have a working simulation or a touch activity written as
JSON in its lesson file. No Dart per topic: the board draws them from data. The pack builder
checks them (`node tools/pack-builder/dist/validate.js`) and refuses anything that would show
`NaN`, cannot be solved, or uses a name it does not know.

The schema is the judge: `packages/lesson-schema/src/index.ts` (`InteractiveBlock`,
`ChallengeBlock`, `ActivityBlock`, `Shape`). Worked, validated examples live in these lessons
(search for the block id):

| Block id | Lesson | Shows |
| --- | --- | --- |
| `scene-projectile` | puc1-physics-motion-in-a-plane t4 | time, Launch button, trail, toggles, `stopWhen` |
| `challenge-launch` | puc1-physics-motion-in-a-plane t4 | a scene challenge: lock in launches, goal taken where it lands |
| `scene-pendulum` | puc1-physics-oscillations t5 | `state` + RK2 integrator, energy bars, damping toggle |
| `scene-lens` | puc2-physics-ray-optics-and-optical-instruments t4 | draggable handle, rays from vars, `lens` icon |
| `scene-rc` | puc2-physics-electrostatic-potential-and-capacitance t4 | circuit icons, switch toggle, integrator, live graph by trail |
| `scene-wave` | puc1-physics-waves t3 | `wave` shape, autoplay loop |
| `scene-gas` | puc1-physics-kinetic-theory t3 | `particles`, `rand`, `bounce`, choice, colour scale |
| `scene-enzyme` | puc1-biology-biomolecules t5 | graph + model side by side, shape swap with `visibleIf` |
| `scene-demand-supply` | puc2-economics-market-equilibrium t2 | handle on one axis shifts a curve |
| `activity-mitosis-order` | puc1-biology-cell-cycle-and-cell-division t2 | `order`, recorded with `questionId` |
| `activity-sort-alc` | puc1-accountancy-introduction-to-accounting t5 | `sort` into 3 buckets |
| `activity-match-fayol` | puc2-business-studies-principles-of-management t4 | `match` |
| `activity-poem-order` | puc2-english-keeping-quiet-poem t3 | `order` of summaries in our own words |
| `activity-fill-franz` | puc2-english-the-last-lesson t2 | `fill` |

## 1. Which block?

- **`interactive`**: something to explore. `kind` is one of the classic charts
  (`function_plot`, `vectors`, `bar_chart`, `pie_chart`, `unit_circle`, `number_line`,
  `readouts`) or **`scene`**, an animated drawing.
- **`challenge`**: the same playfield plus a target to hit for stars (see the existing
  challenge rules in the schema). A challenge may be a scene.
- **`activity`**: for ideas that are not numbers: `sort`, `order`, `match`, `label`,
  `hotspot`, `fill`.

Place a new block right after the first `concept` of the lesson unless the lesson needs it
elsewhere. Give it a `title`, a `narration` (read aloud in Self-Learning) and, for scenes, a
`seconds` (how long Self-Learning shows it; 90–120 for a scene).

## 2. The expression language

Every number in a scene may be a string expression. The same language is used by the board
(Dart) and the validator (TypeScript); `tools/pack-builder/src/expr-cases.json` lists cases
both must agree on.

- Numbers `2`, `0.5`, `.5`, `1e-3`; constants `pi`, `e`. Write every multiplication: `2*x`.
- Operators, loosest first: `||` · `&&` · `< > <= >= == !=` · `+ -` · `* /` · unary `- + !` ·
  `^` (right to left). So `-x^2` is `-(x^2)`, `2^3^2` is 512, and `a + 1 < b*2 && c` compares
  the sums first. Comparisons and logic give **1 or 0**; any non-zero number counts as true
  (NaN is false). Comparisons do not chain: write `0 < x && x < 5`, not `0 < x < 5`.
- One-argument functions: `sin cos tan asin acos atan sqrt exp ln log abs floor ceil round
  sign rad deg rand`. Trig is in **radians**: use `sin(rad(a))` for an angle in degrees.
  `round(x)` is `floor(x + 0.5)`. `log` is base 10, `ln` natural.
- More arguments: `min(a, b, …)`, `max(a, b, …)`, `clamp(v, lo, hi)`, `if(c, a, b)` (only the
  chosen branch is worked out), `mod(a, b)` (floored: `mod(-1, 3) = 2`), `pow(a, b)`,
  `hypot(a, b)`, `atan2(y, x)`, `step(edge, v)` (0 below the edge, 1 from it),
  `smoothstep(e0, e1, v)`, `bounce(v, lo, hi)` (folds v back and forth between two walls, like a
  ball in a box), `rand(k)` (a repeatable number in [0, 1) for each whole k).

**Names an expression may use** (the validator rejects anything else):

| Where | Names |
| --- | --- |
| `vars[n].expr` | controls, `t`, state, vars before it |
| `state[].init` | controls only |
| `state[].rate`, shapes, readouts, `goal`, `time.stopWhen`, button `set` | controls, `t`, state, all vars |
| `fns[].fn`, `path.fn`, `wave.fn` | the above plus `x` |
| a `particles` shape | the above plus `i` (0 … count − 1) |

Controls are slider, toggle, choice and counter names and `<handle>_x`, `<handle>_y`. `t`
exists only when the block has `time`. Names are letters, digits and `_`, starting with a
letter; they must not repeat and must not be a function or constant name (`min`, `step`, `e`…),
`x`, `t` (with time) or `i` (with particles).

## 3. Controls (any interactive or challenge)

```json
"sliders":  [{ "name": "v", "label": {"en": "Speed", "kn": "ವೇಗ"}, "min": 5, "max": 25, "step": 1, "value": 15, "unit": "m/s" }],
"toggles":  [{ "name": "vec", "label": {"en": "Velocity arrows"}, "value": true }],
"choices":  [{ "name": "M", "label": {"en": "Gas"}, "options": [{"label": {"en": "He"}, "value": 4}, {"label": {"en": "N₂"}, "value": 28}], "value": 28 }],
"counters": [{ "name": "gen", "value": 0, "min": 0, "max": 10 }],
"buttons":  [{ "label": {"en": "Next generation"}, "icon": "next", "set": {"gen": "gen + 1"} },
             { "label": {"en": "Launch"}, "icon": "launch", "reset": true, "play": true }],
"handles":  [{ "name": "O", "label": "object", "x": -25, "y": 4, "box": {"x": [-45, -3], "y": [1, 8]}, "snap": 0.5, "color": "yellow" }]
```

- **sliders** (up to 4): `value` inside `min`…`max`. A challenge needs at least one.
- **toggles** (up to 4): the name is 1 when on, 0 when off. Use them with `visibleIf` or
  `if(name, a, b)`.
- **choices** (up to 3, 2–6 options): the name takes the chosen option's `value`; the
  starting `value` must be one of them, and option values must differ.
- **counters** (up to 4): numbers only buttons change (electrons added, generation). They are
  not reset by the time Reset.
- **buttons** (up to 4): `set` maps sliders, toggles, choices or counters to expressions
  worked out with the values *before* the press (sliders snap to their step and stay in range;
  counters stay within min/max). `reset` rewinds time, `play` starts it. Icons: `play add remove
  next reset launch flip check`.
- **handles** (up to 4, scenes only): points the class drags. The position is
  `<name>_x`, `<name>_y`. Limit them with `box` (the view when absent), `axis: "x"` or `"y"`
  (moves only that way), or `line: [[x1, y1], [x2, y2]]` (slides on a segment); `snap` rounds
  to a grid. The start must be inside the box.

All controls are drawn large (one board tap target high) and wrap on a phone.

## 4. Time

```json
"time": { "min": 0, "max": 6, "loop": false, "speeds": [0.25, 0.5, 1, 2, 4], "speed": 1, "autoplay": false, "stopWhen": "landed", "dt": 0.01, "unit": "s" }
```

Only `max` is required. The board shows Play/Pause, Step, Reset, a scrubber, the time and the
speed (tap to cycle `speeds`; `speed` must be one of them). Time runs only while playing and
while the block is on screen. At `max` it stops (or starts again with `loop`). `stopWhen`
pauses it as soon as the expression is true. Without `state`, `t` is continuous (smooth slow
motion); with `state`, it moves in steps of `dt`. Keep `(max − min) / dt` under 20 000.

A challenge hides the time bar until it is over, so the class reasons first; Lock in plays the
try from the start.

## 5. Derived variables and the integrator

```json
"vars": [
  { "name": "px", "expr": "v*cos(rad(a))*t" },
  { "name": "py", "expr": "max(v*sin(rad(a))*t - 4.9*t^2, 0)" },
  { "name": "landed", "expr": "t > 0 && v*sin(rad(a))*t - 4.9*t^2 <= 0" }
],
"state": [
  { "name": "th", "init": "rad(th0)", "rate": "w" },
  { "name": "w",  "init": 0,          "rate": "-9.8/L*sin(th) - b*w" }
],
"integrator": "rk2"
```

- **vars** (up to 24) are worked out in order every frame: write the physics once and use the
  names everywhere (shapes, readouts, the goal). Use them for closed forms.
- **state** (up to 8, needs `time`) is for what closed forms cannot do: large-angle pendulums,
  damping, RC with a switch, populations, predator–prey, cooling. Each variable starts at `init`
  and changes at `rate` (its d/dt). Each step of `dt`: the vars are worked out, then
  `rk2` (default; midpoint method) or `euler` moves the state. It is deterministic: Reset and
  the scrubber run it again from the start, and the board and the validator get the same numbers.
  Use `rk2`; make `dt` at most a tenth of the fastest time scale (for RC, `dt ≤ RC/10`; for a
  pendulum `dt = 0.005` is plenty).
- Changing a slider before pressing Play restarts the state from its new `init`.

## 6. Scenes

```json
"kind": "scene",
"view": { "x": [0, 65], "y": [0, 33], "axes": true, "grid": true, "xLabel": "x (m)", "yLabel": "y (m)", "equal": true },
"shapes": [ … drawn back to front, up to 60 … ]
```

`view` is the world window (x right, y **up**). `equal: true` keeps circles round and angles
true (use it for geometry, optics, mechanics). Shapes are in world units, except `width`
(line thickness), `size` (text) and `amp` (spring zig-zag), which are board points (1920 ×
1080 canvas; phones scale the whole canvas).

Every shape may have `visibleIf` (drawn only when true), `color` (an ink: `white yellow red
green blue orange`, or a scale `{"by": "(T - 100)/900", "scale": ["blue", "yellow", "red"]}`
blended by a 0…1 value) and `opacity` (0…1). Every number may be an expression.

| shape | fields | notes |
| --- | --- | --- |
| `circle` | `x y r`, `fill` (true), `width` | `r` in x units |
| `rect` | `x y w h`, `fill` (true), `width` | (x, y) is the bottom-left corner; bars of a chart |
| `line` | `x1 y1 x2 y2`, `dashed`, `width` | rays, strings, wires, guides |
| `arrow` | `x y dx dy`, `label`, `width` | a vector from (x, y) by (dx, dy): forces, velocities, fields |
| `path` | `fn` (y of x) with `from`/`to` (the view by default), or `points` `[[x, y]…]`; `closed`, `dashed` | curves, graphs; undefined parts are left out |
| `polygon` | `points` (3+), `fill` (true) | shapes, cells, enzymes, prisms |
| `wave` | `fn` (y of x and t), `from`, `to` | a smooth travelling or standing wave |
| `text`, `label` | `x y text`, `size` (30), `align` (center/left/right) | `{expr}` shows a value, `{expr:2}` with 2 decimals; a label has a dark pill behind it |
| `spring` | `x1 y1 x2 y2`, `coils` (10), `amp` (14) | SHM, collisions |
| `trail` | `x y`, `length` (300 points) | traces a point while time runs; a live graph when x is `t` |
| `particles` | `count` (≤ 400), `x y r`, may use `i` | gases, diffusion, electron flow, populations |
| `icon` | `icon`, `x y size`, `angle` (degrees), `on` (0…1) | `bulb battery resistor capacitor switch magnet lens mirror cell beaker`; `on` lights a bulb, closes a switch, fills a beaker |

**Particles that move about a box**: give each a random start and a random velocity with
`rand`, and keep it in the box with `bounce`:

```json
{ "shape": "particles", "count": 60, "r": 0.17,
  "x": "bounce(0.2 + 9.6*rand(i) + s*t*cos(2*pi*rand(i + 300))*(0.4 + rand(i + 900)), 0.2, 9.8)",
  "y": "bounce(0.2 + 9.6*rand(i + 150) + s*t*sin(2*pi*rand(i + 300))*(0.4 + rand(i + 900)), 0.2, 9.8)" }
```

Use different offsets (`i + 150`, `i + 300`…) for numbers that must not be related. To show
only some (electrons added by a button), use `"visibleIf": "i < n"`.

### Worked example: a damped spring (state + spring + trail as a graph)

```json
{
  "id": "scene-spring", "type": "interactive", "kind": "scene", "seconds": 90,
  "title": {"en": "A mass on a spring"},
  "caption": {"en": "Pull the mass and let go. With damping on, each swing is smaller."},
  "sliders": [{ "name": "k", "label": {"en": "Spring constant"}, "min": 5, "max": 50, "step": 5, "value": 20, "unit": "N/m" }],
  "toggles": [{ "name": "damp", "label": {"en": "Damping"}, "value": false }],
  "time": { "max": 20, "dt": 0.005 },
  "state": [{ "name": "x1", "init": 0.5, "rate": "u" }, { "name": "u", "init": 0, "rate": "-k/2*x1 - if(damp, 0.4, 0)*u" }],
  "view": { "x": [-1, 12], "y": [-1.2, 1.2] },
  "shapes": [
    { "shape": "spring", "x1": -1, "y1": 0, "x2": "x1 + 0.6", "y2": 0, "coils": 12 },
    { "shape": "rect", "x": "x1 + 0.6", "y": -0.3, "w": 0.6, "h": 0.6, "color": "orange" },
    { "shape": "trail", "x": "2 + t/2", "y": "x1", "length": 2000, "color": "yellow" }
  ],
  "readouts": [{ "label": {"en": "Period 2π√(m/k)"}, "expr": "2*pi*sqrt(2/k)", "unit": "s" }]
}
```

### Worked example: a scene challenge

Lock in runs the model from the start with the class's settings until `stopWhen` (or the end
of time); the goal is taken there. The solution must hit it and the starting values must not.

```json
{ "id": "challenge-launch", "type": "challenge", "kind": "scene",
  "prompt": {"en": "Land the ball on the flag at x = 40 m."},
  "sliders": [ …v 10–30, a 10–80… ],
  "time": { "max": 6.5, "stopWhen": "landed" },
  "vars": [ …px, py, landed as above… ],
  "view": { "x": [0, 70], "y": [0, 30], "axes": true, "equal": true },
  "shapes": [ …flag at x = 40, trail, ball… ],
  "goal": "px", "goalLabel": {"en": "Landing point"}, "goalUnit": "m",
  "target": 40, "tolerance": 1.5, "solution": { "v": 20, "a": 40 },
  "explanation": {"en": "R = v² sin 2θ / g ≈ 40.2 m."} }
```

The solution must give every slider (on its step); it may also set toggles, choices and
handle coordinates (`O_x`) to values they can take.

## 7. Activities

Every activity has `kind`, a `prompt` (read aloud and shown at the top), an optional
`explanation` (shown after a correct Check or Show answer) and optional `questionId`: with it,
the class's first Check is recorded as one whole-class answer (source `activity`) in the
mastery store and the session log. Use an id like `act.<topic>-<what>`. The board gives Check
(marks each item right or wrong), Show answer and Start again, and accepts drag or
tap-then-tap. Shuffles are fixed by the block id and never start solved.

**sort**: 2–4 `buckets`, 2–16 `items`; each item's `answer` is a bucket id; every bucket gets
at least one item.

```json
{ "id": "activity-sort-alc", "type": "activity", "kind": "sort",
  "prompt": {"en": "Sort each item into Assets, Liabilities or Capital."},
  "buckets": [{"id": "asset", "label": {"en": "Assets"}}, {"id": "liability", "label": {"en": "Liabilities"}}, {"id": "capital", "label": {"en": "Capital"}}],
  "items": [{"text": {"en": "Cash in hand"}, "answer": "asset"}, {"text": {"en": "Creditors"}, "answer": "liability"}, {"text": {"en": "Owner's money brought in"}, "answer": "capital"}] }
```

**order**: 3–10 `steps`, written in the **right** order (the board shuffles them).

```json
{ "id": "activity-mitosis-order", "type": "activity", "kind": "order", "questionId": "act.mitosis-order",
  "prompt": {"en": "Arrange the stages of mitosis in order."},
  "steps": [{"en": "Prophase: …"}, {"en": "Metaphase: …"}, {"en": "Anaphase: …"}, {"en": "Telophase: …"}] }
```

**match**: 2–8 `pairs` of `left` and `right`; the right-hand cards are shuffled.

```json
{ "kind": "match", "pairs": [{"left": {"en": "Unity of command"}, "right": {"en": "An operator takes orders only from her supervisor"}}, …] }
```

**label**: a diagram (`view` + `shapes`, constants only) and 2–10 `targets`, each a spot
(`x y` and `r`, or `w h` for a box) with its `label`; add up to 4 wrong `distractors`. The
class drags each label onto its spot.

```json
{ "kind": "label", "prompt": {"en": "Label the cell."},
  "view": {"x": [0, 10], "y": [0, 6]},
  "shapes": [{"shape": "circle", "x": 5, "y": 3, "r": 2.6, "fill": false, "color": "green"}, {"shape": "circle", "x": 5, "y": 3, "r": 0.8, "color": "blue"}],
  "targets": [{"id": "nucleus", "x": 5, "y": 3, "r": 0.8, "label": {"en": "Nucleus"}}, {"id": "membrane", "x": 7.6, "y": 3, "r": 0.4, "label": {"en": "Cell membrane"}}],
  "distractors": [{"en": "Cell wall"}] }
```

**hotspot**: the same diagram and targets; `answer` lists the right target ids (at least one,
not all). The class taps the right spots; names appear after Check.

```json
{ "kind": "hotspot", "prompt": {"en": "Tap the part that controls the cell."}, "view": …, "shapes": …, "targets": …, "answer": ["nucleus"] }
```

**fill**: a `passage` with blanks `__1__`, `__2__` … (each once, in order) and `blanks[n-1]`
with 2–5 `options` and the `answer` index (0 = first). A Kannada passage, if given, must have
the same blanks.

```json
{ "kind": "fill", "prompt": {"en": "Complete this retelling."},
  "passage": {"en": "Franz had not learnt the rule for __1__, and a crowd stood at the __2__."},
  "blanks": [{"options": [{"en": "participles"}, {"en": "fractions"}], "answer": 0}, {"options": [{"en": "school gate"}, {"en": "bulletin board"}], "answer": 1}] }
```

## 8. Rules

**Units and ranges**
- Pick SI-friendly units and say them: slider `unit`, readout `unit`, axis labels
  (`"x (m)"`). Keep numbers the class can read: kΩ and µF, not 4.7e-4 F; scale inside vars
  (`tau = R*C/1000` for kΩ × µF → s).
- Make the view fit every setting the sliders allow (the validator runs min, max, every
  choice and flipped toggles; it does not judge whether things fall off screen, so try them).
- Sliders: 10–60 steps from min to max. Time: a few seconds to a minute of model time.

**What the validator rejects**
- An expression that does not compile or uses an unknown name.
- A drawn value that is NaN or infinite at any time for any tried setting (hidden shapes are
  skipped, so guard with `visibleIf` or `if()`: `"v": "if(nearF, 1000, u*f/den)"`). A `path`
  may be undefined in places but not everywhere.
- Name clashes; `t` without time; state without time; trail without time; handles or shapes
  on a kind other than scene; buttons that set an unknown name or do nothing.
- Challenges that the solution does not hit, or that the start already hits.
- Activities with an item in no bucket, a bucket with no item, repeated items, targets outside
  the view, a hotspot whose every target is right, fill blanks out of order.

**What to avoid**
- Long inline LaTeX in captions: the side panel is narrow on a phone and a formula does not
  wrap. Keep `$…$` short (`$\tau = RC$`) or write it in plain text (`1/v − 1/u = 1/f`).
- Reproducing copyrighted text (poems, prose) in activities: write summaries and retellings in
  our own words.
- Readouts that give away a challenge's goal.
- Student names anywhere (roll numbers only, and only the board records them).
- Particles that depend on a slider through `s*t` jump when the slider moves mid-run; that is
  fine for gases, but use `state` when a smooth change matters.
- More than about 400 particles or 60 shapes: the board must stay smooth at 60 fps.
- Kannada: give `kn` for titles, captions, labels and prompts where you can; it is reviewed
  by a native speaker before release. Plain formula text (`{px:1} m`) can stay English-only.

**Check before you commit**

```sh
cd packages/lesson-schema && pnpm build          # after schema changes only
cd tools/pack-builder && pnpm build && node dist/validate.js <pack-dir>
```

Then open the lesson on a board build and on a phone, play it through once at 1× and once at
4×, and try the extreme slider settings.
