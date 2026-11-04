"""Adds one `challenge` block (a playable slider problem: hit a target, earn stars) to lessons in
Physics, Chemistry, Maths, Accountancy, Economics and Statistics, both years.

Every challenge is checked here before it is written, with the same expression language as the
board (tools/pack-builder/src/expr.ts): the solution's slider values must be reachable (inside
min..max, on the slider's step), must put the goal within tolerance of the target, and the
starting values must not. The pack validator checks the same again.

Run from anywhere:  python3 tools/content-src/add_challenges.py   (idempotent: it replaces the
block with id `challenge1` if a lesson already has one). Then:
    node tools/pack-builder/dist/validate.js <pack dirs…>
"""
import json, math, pathlib, re

PACKS = pathlib.Path(__file__).resolve().parents[2] / 'content' / 'packs'
BLOCK_ID = 'challenge1'

# ------------------------------------------------------------------ expression check (board language)
_FNS = {'sin': math.sin, 'cos': math.cos, 'tan': math.tan, 'asin': math.asin, 'acos': math.acos, 'atan': math.atan,
        'sqrt': math.sqrt, 'exp': math.exp, 'ln': math.log, 'log': math.log10, 'abs': abs, 'floor': math.floor}
_TOKEN = re.compile(r'\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[A-Za-z_]\w*|\S)')


def evaluate(src, names, vars):
    """Evaluates `src` exactly as the board does (precedence: + - < * / < unary minus < ^)."""
    t = [m.group(1) for m in _TOKEN.finditer(src)]
    i = 0

    def peek():
        return t[i] if i < len(t) else None

    def nxt():
        nonlocal i
        i += 1
        return t[i - 1] if i - 1 < len(t) else None

    def expr():
        v = term()
        while peek() in ('+', '-'):
            v = v + term() if nxt() == '+' else v - term()
        return v

    def term():
        v = unary()
        while peek() in ('*', '/'):
            if nxt() == '*':
                v = v * unary()
            else:
                d = unary()
                v = v / d if d != 0 else math.copysign(math.inf, v) if v else math.nan
        return v

    def unary():
        if peek() == '-':
            nxt()
            return -unary()
        if peek() == '+':
            nxt()
            return unary()
        return power()

    def power():
        b = primary()
        if peek() == '^':
            nxt()
            ex = unary()
            try:
                return math.pow(b, ex)
            except (ValueError, OverflowError):
                return math.nan
        return b

    def primary():
        tok = nxt()
        if tok is None:
            raise ValueError(f'{src}: ends too early')
        if tok == '(':
            v = expr()
            if nxt() != ')':
                raise ValueError(f'{src}: missing )')
            return v
        if re.match(r'[\d.]', tok):
            return float(tok)
        if re.match(r'[A-Za-z_]', tok):
            if tok in _FNS:
                if nxt() != '(':
                    raise ValueError(f'{src}: {tok} needs (…)')
                a = expr()
                if nxt() != ')':
                    raise ValueError(f'{src}: missing )')
                try:
                    return float(_FNS[tok](a))
                except (ValueError, OverflowError):
                    return math.nan
            if tok == 'pi':
                return math.pi
            if tok == 'e':
                return math.e
            if tok not in names:
                raise ValueError(f'{src}: unknown name {tok}')
            return vars[tok]
        raise ValueError(f'{src}: unexpected {tok}')

    v = expr()
    if i < len(t):
        raise ValueError(f'{src}: unexpected {t[i]}')
    return v


# ------------------------------------------------------------------ authoring helpers
def L(en, kn=None):
    return {'en': en, **({'kn': kn} if kn else {})}


def S(name, label, mn, mx, step, value, unit=None):
    return {'name': name, 'label': L(label), 'min': mn, 'max': mx, 'step': step, 'value': value, **({'unit': unit} if unit else {})}


CHALLENGES = []


def ch(pack, topic, name, prompt, sliders, goal, goal_label, target, tol, solution, explanation, hint=None, unit=None, mode='team', attempts=3, time_limit=None, **play):
    """One challenge. `play` holds the playfield (kind, fns, x, y, data, points, vectors, readouts…);
    by default a bar chart of the slider settings."""
    if 'kind' not in play:
        play = {'kind': 'bar_chart', 'data': {s['label']['en'].split(' (')[0][:14]: s['name'] for s in sliders}, **play}
    CHALLENGES.append(dict(pack=pack, topic=topic, block={
        'id': BLOCK_ID, 'type': 'challenge', 'title': L(f'Challenge: {name}', 'ಸವಾಲು'),
        'narration': L(prompt), **play, 'prompt': L(prompt), 'sliders': sliders,
        'goal': goal, 'goalLabel': L(goal_label), **({'goalUnit': unit} if unit else {}),
        'target': target, 'tolerance': tol, 'solution': solution, 'attempts': attempts,
        **({'timeLimit': time_limit} if time_limit else {}), 'mode': mode,
        **({'hint': L(hint)} if hint else {}), 'explanation': L(explanation),
    }))


def check(c):
    b = c['block']
    names = [s['name'] for s in b['sliders']]
    sol, start = b['solution'], {s['name']: s['value'] for s in b['sliders']}
    where = f"{c['pack']}/{c['topic']}"
    assert set(sol) == set(names), f'{where}: solution must set every slider'
    for s in b['sliders']:
        v = sol[s['name']]
        assert s['min'] - 1e-9 <= v <= s['max'] + 1e-9, f"{where}: {s['name']}={v} outside range"
        k = (v - s['min']) / s['step']
        assert abs(k - round(k)) < 1e-6, f"{where}: {s['name']}={v} not on step {s['step']}"
    hit = evaluate(b['goal'], names, sol)
    assert abs(hit - b['target']) <= b['tolerance'] + 1e-9, f"{where}: solution gives {hit}, target {b['target']} ± {b['tolerance']}"
    s0 = evaluate(b['goal'], names, start)
    assert not (abs(s0 - b['target']) <= b['tolerance']), f'{where}: starting values already hit ({s0})'
    for f in b.get('fns', []):
        xs = [b['x'][0], (b['x'][0] + b['x'][1]) / 2, b['x'][1]]
        vals = [evaluate(f['fn'], ['x', *names], {**start, 'x': x}) for x in xs]
        assert any(math.isfinite(v) for v in vals), f"{where}: fn {f['fn']} not a number"
    for v in list(b.get('data', {}).values()) + list(b.get('points', [])) + [e for p in b.get('vectors', []) for e in p]:
        if isinstance(v, str):
            evaluate(v, names, start)
    return hit


# ================================================================== PHYSICS
TRAJ = 'x*tan(a*pi/180) - 9.8*x^2/(2*v^2*cos(a*pi/180)^2)'
ch('puc1-physics-motion-in-a-plane', 't4', 'Hit the target',
   'A ball is launched from the ground. Set its speed and angle so it lands exactly on the flag at x = 40 m.',
   [S('v', 'Speed', 10, 30, 1, 15, 'm/s'), S('a', 'Angle', 10, 80, 1, 30, '°')],
   'v^2*sin(2*a*pi/180)/9.8', 'Landing point', 40, 1, {'v': 20, 'a': 40},
   'Range R = v² sin 2θ / g. With 20 m/s at 40°: 400 × 0.985 / 9.8 ≈ 40.2 m. Other pairs work too: any v and θ with v² sin 2θ ≈ 392.',
   hint='R = v² sin 2θ / g. The range is largest at 45°.', unit='m',
   kind='function_plot', fns=[{'fn': TRAJ, 'label': 'path', 'color': 'yellow'}], x=[0, 60], y=[0, 30], xLabel='x (m)', yLabel='height (m)')
ch('puc1-physics-motion-in-a-straight-line', 't4', 'The 100 m launch',
   'A car starts from rest with constant acceleration. Choose the acceleration and time so it covers exactly 100 m.',
   [S('a', 'Acceleration', 0.5, 5, 0.5, 1, 'm/s²'), S('t', 'Time', 1, 20, 1, 5, 's')],
   '0.5*a*t^2', 'Distance covered', 100, 2, {'a': 2, 't': 10},
   's = ut + ½at² with u = 0: ½ × 2 × 10² = 100 m. (a = 0.5, t = 20 also works.)', hint='From rest, s = ½ a t².', unit='m')
ch('puc1-physics-motion-in-a-straight-line', 't5', 'Three-second drop',
   'From what height must a stone be dropped so that it takes exactly 3 s to reach the ground? (g = 9.8 m/s²)',
   [S('h', 'Height', 5, 100, 0.1, 20, 'm')], 'sqrt(2*h/9.8)', 'Fall time', 3, 0.02, {'h': 44.1},
   'h = ½ g t² = ½ × 9.8 × 9 = 44.1 m.', hint='h = ½ g t².', unit='s', mode='roll_call')
ch('puc1-physics-laws-of-motion', 't4', 'Pull against friction',
   'A 10 kg crate rests on a floor with μk = 0.2. With what force must you pull it so it accelerates at exactly 1.5 m/s²?',
   [S('F', 'Pull', 0, 100, 0.2, 20, 'N')], '(F - 0.2*10*9.8)/10', 'Acceleration', 1.5, 0.02, {'F': 34.6},
   'Friction = μmg = 0.2 × 10 × 9.8 = 19.6 N. F − 19.6 = ma = 15, so F = 34.6 N.', hint='Net force = F − μmg = ma.', unit='m/s²')
ch('puc1-physics-work-energy-and-power', 't3', 'Reach the top',
   'A roller-coaster car must just reach a hill 20 m high with no friction. What speed must it have at the bottom?',
   [S('v', 'Speed at bottom', 5, 30, 0.1, 10, 'm/s')], 'v^2/(2*9.8)', 'Height reached', 20, 0.3, {'v': 19.8},
   '½mv² = mgh, so v = √(2gh) = √392 ≈ 19.8 m/s. The mass cancels.', hint='Kinetic energy at the bottom becomes potential energy at the top.', unit='m')
ch('puc1-physics-gravitation', 't4', 'Build an Earth',
   'Design a planet with the same escape speed as Earth, 11.2 km/s. Choose its mass and radius.',
   [S('M', 'Mass (×10²⁴ kg)', 1, 20, 0.01, 2), S('R', 'Radius (×10⁶ m)', 2, 20, 0.01, 8)],
   'sqrt(2*6.67*10^-11*M*10^24/(R*10^6))/1000', 'Escape speed', 11.2, 0.1, {'M': 5.97, 'R': 6.37},
   'vₑ = √(2GM/R). Earth: M = 5.97 × 10²⁴ kg, R = 6.37 × 10⁶ m gives 11.2 km/s. Any planet with the same M/R works.', hint='vₑ = √(2GM/R): only the ratio M/R matters.', unit='km/s')
ch('puc1-physics-oscillations', 't5', 'The seconds pendulum',
   'Set the length of a simple pendulum so its period is exactly 2 s (g = 9.8 m/s²).',
   [S('Lp', 'Length', 0.1, 3, 0.01, 0.5, 'm')], '2*pi*sqrt(Lp/9.8)', 'Period', 2, 0.02, {'Lp': 0.99},
   'T = 2π√(L/g) gives L = gT²/4π² = 9.8 × 4 / 39.5 ≈ 0.99 m: the "seconds pendulum".', hint='T = 2π√(L/g).', unit='s',
   kind='function_plot', fns=[{'fn': '0.1*sin(2*pi*x/(2*pi*sqrt(Lp/9.8)))', 'label': 'swing', 'color': 'yellow'}], x=[0, 6], y=[-0.15, 0.15], xLabel='t (s)', yLabel='θ (rad)')
ch('puc1-physics-waves', 't3', 'Tune the string',
   'A stretched string must carry waves at exactly 100 m/s. Choose its tension and its mass per unit length.',
   [S('T', 'Tension', 10, 500, 5, 50, 'N'), S('mu', 'Mass per length', 0.005, 0.05, 0.005, 0.02, 'kg/m')],
   'sqrt(T/mu)', 'Wave speed', 100, 1, {'T': 100, 'mu': 0.01},
   'v = √(T/μ) = √(100/0.01) = 100 m/s. Doubling μ needs double the tension.', hint='v = √(T/μ).', unit='m/s')
ch('puc1-physics-thermal-properties-of-matter', 't3', 'Perfect bath water',
   'You have 200 g of water at 20 °C. How much water at 80 °C must you add to get a mixture at 40 °C? (no heat lost)',
   [S('m', 'Hot water', 10, 400, 10, 50, 'g')], '(m*80 + 200*20)/(m + 200)', 'Final temperature', 40, 0.2, {'m': 100},
   'Heat lost = heat gained: m × 40 = 200 × 20, so m = 100 g.', hint='m₁c(80 − T) = m₂c(T − 20).', unit='°C')
ch('puc1-physics-thermodynamics', 't5', 'A 40% engine',
   'Choose the hot and cold reservoir temperatures of a Carnot engine so its efficiency is exactly 40%.',
   [S('Th', 'Hot reservoir', 300, 800, 10, 400, 'K'), S('Tc', 'Cold reservoir', 250, 400, 10, 300, 'K')],
   '(1 - Tc/Th)*100', 'Efficiency', 40, 0.5, {'Th': 500, 'Tc': 300},
   'η = 1 − T꜀/Tₕ = 1 − 300/500 = 0.4. Temperatures must be in kelvin.', hint='η = 1 − T꜀/Tₕ.', unit='%')
ch('puc1-physics-mechanical-properties-of-solids', 't3', 'Stretch by 1 mm',
   'A steel wire (area 1 mm², Y = 2 × 10¹¹ Pa) must stretch by exactly 1 mm. Choose the load and the wire length.',
   [S('F', 'Load', 10, 500, 10, 50, 'N'), S('Lw', 'Length', 0.5, 4, 0.5, 1, 'm')],
   'F*Lw/(10^-6*2*10^11)*1000', 'Extension', 1, 0.02, {'F': 100, 'Lw': 2},
   'ΔL = FL/(AY) = 100 × 2 / (10⁻⁶ × 2 × 10¹¹) = 10⁻³ m = 1 mm.', hint='ΔL = FL / AY.', unit='mm')
ch('puc1-physics-system-of-particles-and-rotational-motion', 't3', 'Balance the seesaw',
   'A 30 kg child sits 2 m from the pivot. Place a second child (choose the mass and distance) on the other side so the seesaw balances.',
   [S('m', 'Mass', 10, 50, 5, 25, 'kg'), S('d', 'Distance', 0.5, 4, 0.1, 1, 'm')],
   'm*d - 30*2', 'Net turning effect (anticlockwise − clockwise)', 0, 0.5, {'m': 20, 'd': 3},
   'Balance: torques equal, m × d = 30 × 2 = 60 kg m. A 20 kg child at 3 m works.', hint='Moments about the pivot must be equal.', unit='kg m')
ch('puc2-physics-current-electricity', 't4', 'Ten volts out',
   'A cell has emf 12 V and internal resistance 1 Ω. Choose the external resistance so the terminal voltage is exactly 10 V.',
   [S('R', 'External R', 0.5, 20, 0.5, 2, 'Ω')], '12*R/(R + 1)', 'Terminal voltage', 10, 0.05, {'R': 5},
   'I = E/(R + r) = 12/6 = 2 A; V = IR = 10 V (the lost volts Ir = 2 V).', hint='V = E − Ir, I = E/(R + r).', unit='V')
ch('puc2-physics-current-electricity', 't5', 'Balance the bridge',
   'In a Wheatstone bridge P = 10 Ω, Q = 20 Ω and R = 15 Ω. Set S so the galvanometer shows no current.',
   [S('Sr', 'S', 5, 60, 1, 20, 'Ω')], '10/20 - 15/Sr', 'P/Q − R/S', 0, 0.002, {'Sr': 30},
   'Balanced when P/Q = R/S: 10/20 = 15/S, so S = 30 Ω.', hint='Balance condition: P/Q = R/S.')
ch('puc2-physics-electrostatic-potential-and-capacitance', 't5', '1.2 microfarad',
   'Join two capacitors in series to get exactly 1.2 μF. Choose them.',
   [S('C1', 'C₁', 1, 10, 1, 4, 'μF'), S('C2', 'C₂', 1, 10, 1, 4, 'μF')],
   'C1*C2/(C1 + C2)', 'Series capacitance', 1.2, 0.01, {'C1': 2, 'C2': 3},
   '1/C = 1/2 + 1/3 = 5/6, so C = 1.2 μF. In series the total is less than either.', hint='In series, 1/C = 1/C₁ + 1/C₂.', unit='μF')
ch('puc2-physics-moving-charges-and-magnetism', 't2', 'Proton in orbit',
   'A proton enters a uniform magnetic field at right angles. Choose its speed and the field so it circles with radius 5 cm.',
   [S('v', 'Speed (×10⁶ m/s)', 0.5, 5, 0.1, 1), S('B', 'Field', 0.1, 2, 0.1, 1, 'T')],
   '1.67*10^-27*v*10^6/(1.6*10^-19*B)*100', 'Radius', 5, 0.05, {'v': 2.4, 'B': 0.5},
   'r = mv/(qB) = 1.67 × 10⁻²⁷ × 2.4 × 10⁶ / (1.6 × 10⁻¹⁹ × 0.5) ≈ 0.050 m.', hint='r = mv / qB.', unit='cm')
ch('puc2-physics-alternating-current', 't3', 'Tune to 1 kHz',
   'Choose L and C so a series LCR circuit resonates at 1000 Hz (within 10 Hz).',
   [S('Lh', 'L', 1, 50, 1, 20, 'mH'), S('C', 'C', 0.5, 10, 0.5, 5, 'μF')],
   '1/(2*pi*sqrt(Lh*10^-3*C*10^-6))', 'Resonant frequency', 1000, 10, {'Lh': 10, 'C': 2.5},
   'f₀ = 1/(2π√LC). With 10 mH and 2.5 μF, LC = 2.5 × 10⁻⁸ s², f₀ ≈ 1007 Hz.', hint='f₀ = 1 / (2π√(LC)).', unit='Hz')
ch('puc2-physics-ray-optics-and-optical-instruments', 't4', 'Focus on the screen',
   'A screen is 60 cm behind a convex lens. Choose the focal length and the object distance so a sharp image falls on the screen.',
   [S('f', 'Focal length', 10, 30, 1, 20, 'cm'), S('d', 'Object distance', 21, 100, 1, 40, 'cm')],
   'f*d/(d - f)', 'Image distance', 60, 0.5, {'f': 20, 'd': 30},
   '1/v − 1/u = 1/f with u = −30 cm, f = +20 cm: 1/v = 1/20 − 1/30 = 1/60, v = 60 cm.', hint='Lens formula 1/v − 1/u = 1/f (u is negative).', unit='cm')
ch('puc2-physics-wave-optics', 't3', 'Fringes 1.5 mm apart',
   "In Young's double-slit experiment, choose the wavelength, screen distance and slit separation so the fringe width is 1.5 mm.",
   [S('lam', 'Wavelength', 400, 700, 10, 500, 'nm'), S('D', 'Screen distance', 0.5, 2, 0.1, 1, 'm'), S('d', 'Slit gap', 0.1, 1, 0.05, 0.5, 'mm')],
   'lam*D/d*0.001', 'Fringe width', 1.5, 0.02, {'lam': 600, 'D': 1, 'd': 0.4},
   'β = λD/d = 600 × 10⁻⁹ × 1 / (0.4 × 10⁻³) = 1.5 × 10⁻³ m.', hint='β = λD / d.', unit='mm')
ch('puc2-physics-dual-nature-of-radiation-and-matter', 't3', 'One-volt electrons',
   'Light falls on sodium (work function 2.3 eV). Choose the wavelength so the fastest photoelectrons have 1.0 eV.',
   [S('lam', 'Wavelength', 200, 700, 1, 500, 'nm')], '1240/lam - 2.3', 'Maximum kinetic energy', 1, 0.02, {'lam': 376},
   'K = hν − φ: the photon needs 3.3 eV, and E (eV) = 1240/λ (nm), so λ ≈ 376 nm.', hint='E (in eV) = 1240 / λ (in nm).', unit='eV')
ch('puc2-physics-atoms', 't3', 'Make the red line',
   'The red Balmer line Hα has photon energy 1.89 eV. Choose the jump (upper and lower levels) in hydrogen that makes it.',
   [S('n1', 'Lower level', 1, 5, 1, 1), S('n2', 'Upper level', 2, 7, 1, 2)],
   '13.6*(1/n1^2 - 1/n2^2)', 'Photon energy', 1.89, 0.01, {'n1': 2, 'n2': 3},
   'E = 13.6 (1/n₁² − 1/n₂²) eV = 13.6 (1/4 − 1/9) = 1.89 eV: the 3 → 2 jump.', hint='Balmer lines end on n = 2.', unit='eV', mode='roll_call')

# ================================================================== CHEMISTRY
ch('puc1-chemistry-some-basic-concepts-of-chemistry', 't5', 'Make 0.5 M NaOH',
   'Make a 0.5 M sodium hydroxide solution (M = 40 g/mol). Choose the mass of NaOH and the final volume.',
   [S('m', 'NaOH mass', 1, 20, 0.5, 2, 'g'), S('V', 'Volume', 100, 1000, 50, 500, 'mL')],
   'm/40/(V/1000)', 'Molarity', 0.5, 0.005, {'m': 4, 'V': 200},
   'M = moles / litres = (4/40) / 0.2 = 0.5 M. 10 g in 500 mL works too.', hint='Molarity = (mass/molar mass) / volume in litres.', unit='M')
ch('puc1-chemistry-equilibrium', 't4', 'pH 4.7',
   'Set the hydrogen ion concentration [H⁺] = a × 10⁻ᵇ M so the solution has pH 4.7.',
   [S('a', 'a', 1, 9.9, 0.1, 1), S('b', 'b (power of ten)', 1, 13, 1, 3)],
   '-log(a*10^(-b))', 'pH', 4.7, 0.02, {'a': 2, 'b': 5},
   'pH = −log(2 × 10⁻⁵) = 5 − log 2 = 5 − 0.30 = 4.70.', hint='pH = −log[H⁺]; log 2 ≈ 0.30.', mode='roll_call')
ch('puc1-chemistry-equilibrium', 't2', 'Hit Kc',
   'For N₂O₄ ⇌ 2NO₂, choose equilibrium concentrations so that Kc = 0.01.',
   [S('no2', '[NO₂]', 0.01, 0.2, 0.01, 0.05, 'M'), S('n2o4', '[N₂O₄]', 0.1, 2, 0.1, 1, 'M')],
   'no2^2/n2o4', 'Kc', 0.01, 0.0002, {'no2': 0.1, 'n2o4': 1},
   'Kc = [NO₂]²/[N₂O₄] = 0.1² / 1 = 0.01. The coefficient 2 becomes a square.', hint='Each concentration is raised to its coefficient.')
ch('puc1-chemistry-thermodynamics', 't5', 'The turning point',
   'A reaction has ΔH = +40 kJ/mol and ΔS = +108 J/(K mol). Find the temperature at which it just becomes spontaneous (ΔG = 0).',
   [S('T', 'Temperature', 250, 500, 1, 300, 'K')], '40 - T*0.108', 'ΔG', 0, 0.1, {'T': 370},
   'ΔG = ΔH − TΔS = 0 gives T = 40 000 / 108 ≈ 370 K. Above it ΔG < 0.', hint='Use the same units: ΔS = 0.108 kJ/(K mol).', unit='kJ/mol')
ch('puc1-chemistry-structure-of-atom', 't3', 'Bohr orbit of 211.6 pm',
   'Choose the orbit n and nuclear charge Z of a one-electron atom so the Bohr radius is 211.6 pm.',
   [S('n', 'n', 1, 6, 1, 1), S('Z', 'Z', 1, 4, 1, 1)], '52.9*n^2/Z', 'Orbit radius', 211.6, 0.5, {'n': 2, 'Z': 1},
   'rₙ = 52.9 n²/Z pm. n = 2, Z = 1 gives 4 × 52.9 = 211.6 pm (so does n = 4 in Be³⁺).', hint='rₙ = 52.9 n² / Z pm.', unit='pm')
ch('puc1-chemistry-redox-reactions', 't2', 'Oxidation number of Cr',
   'Find the oxidation number x of chromium in the dichromate ion Cr₂O₇²⁻.',
   [S('xo', 'x', -2, 8, 1, 0)], '2*xo + 7*(-2)', 'Charge of the ion', -2, 0.1, {'xo': 6},
   '2x + 7(−2) = −2, so x = +6.', hint='Oxygen is −2; the sum equals the charge of the ion.', mode='roll_call')
ch('puc1-chemistry-redox-reactions', 't4', 'Balance the electrons',
   'MnO₄⁻ gains 5 electrons and Fe²⁺ loses 1. Choose the smallest coefficients that balance the electrons.',
   [S('a', 'MnO₄⁻', 1, 5, 1, 1), S('b', 'Fe²⁺', 1, 10, 1, 1)], 'abs(5*a - b) + (a - 1)', 'Electron mismatch', 0, 0.1, {'a': 1, 'b': 5},
   'Electrons gained = electrons lost: 5 × 1 = 1 × 5. MnO₄⁻ + 5Fe²⁺ + 8H⁺ → Mn²⁺ + 5Fe³⁺ + 4H₂O.', hint='Smallest whole numbers: start with one permanganate.')
ch('puc1-chemistry-chemical-bonding-and-molecular-structure', 't5', 'Bond order of O₂',
   'O₂ has 16 electrons. Split them into bonding (Nb) and antibonding (Na) electrons so the bond order is 2.',
   [S('Nb', 'Bonding', 0, 12, 1, 8), S('Na', 'Antibonding', 0, 12, 1, 2)], 'abs((Nb - Na)/2 - 2) + abs(Nb + Na - 16)', 'Mismatch', 0, 0.01, {'Nb': 10, 'Na': 6},
   'Bond order = (Nb − Na)/2 = (10 − 6)/2 = 2, and 10 + 6 = 16 electrons.', hint='Two conditions: Nb + Na = 16 and (Nb − Na)/2 = 2.')
ch('puc1-chemistry-hydrocarbons', 't1', 'Burn propane',
   'Balance C₃H₈ + c O₂ → a CO₂ + b H₂O. Choose a, b and c.',
   [S('a', 'CO₂', 1, 6, 1, 1), S('b', 'H₂O', 1, 8, 1, 1), S('c', 'O₂', 1, 10, 1, 1)],
   'abs(a - 3) + abs(2*b - 8) + abs(2*c - 2*a - b)', 'Atoms out of balance', 0, 0.1, {'a': 3, 'b': 4, 'c': 5},
   'C: a = 3. H: 2b = 8, b = 4. O: 2c = 2a + b = 10, c = 5. C₃H₈ + 5O₂ → 3CO₂ + 4H₂O.', hint='Balance C, then H, then O last.')
ch('puc2-chemistry-solutions', 't4', 'Freeze at −0.93 °C',
   'How many grams of glucose (M = 180) must be dissolved in 500 g of water to lower its freezing point by 0.93 K? (Kf = 1.86 K kg/mol)',
   [S('w', 'Glucose', 5, 100, 5, 20, 'g')], '1.86*w/(180*0.5)', 'ΔTf', 0.93, 0.01, {'w': 45},
   'ΔTf = Kf m, so m = 0.5 mol/kg: 0.25 mol in 0.5 kg, i.e. 0.25 × 180 = 45 g.', hint='Molality = (w/180) / 0.5 kg.', unit='K')
ch('puc2-chemistry-chemical-kinetics', 't4', 'One-eighth left',
   'A first-order reaction: choose its half-life and the time so exactly 12.5% of the reactant is left.',
   [S('t', 'Time', 0, 60, 1, 10, 'min'), S('h', 'Half-life', 5, 20, 1, 10, 'min')],
   '100*0.5^(t/h)', 'Reactant left', 12.5, 0.3, {'t': 30, 'h': 10},
   '12.5% = (1/2)³: three half-lives. With t½ = 10 min that is 30 min.', hint='Each half-life halves what is left.', unit='%',
   kind='function_plot', fns=[{'fn': '100*0.5^(x/h)', 'label': '% left', 'color': 'yellow'}], x=[0, 60], y=[0, 100], xLabel='t (min)', yLabel='% left')
ch('puc2-chemistry-chemical-kinetics', 't5', 'Double for 10 degrees',
   'Choose the activation energy so the rate exactly doubles between 300 K and 310 K.',
   [S('Ea', 'Ea', 10, 100, 0.1, 30, 'kJ/mol')], 'exp(Ea*1000/8.314*(1/300 - 1/310))', 'k₃₁₀ / k₃₀₀', 2, 0.02, {'Ea': 53.6},
   'ln(k₂/k₁) = (Ea/R)(1/T₁ − 1/T₂): ln 2 = Ea × 1.075 × 10⁻⁴ / 8.314, so Ea ≈ 53.6 kJ/mol.', hint='Arrhenius: ln(k₂/k₁) = (Ea/R)(1/T₁ − 1/T₂).')
ch('puc2-chemistry-electrochemistry', 't2', 'Push the cell to 1.13 V',
   'A Daniell cell (E° = 1.10 V, n = 2). Choose [Zn²⁺] and [Cu²⁺] so the cell gives 1.13 V.',
   [S('zn', '[Zn²⁺]', 0.01, 1, 0.01, 1, 'M'), S('cu', '[Cu²⁺]', 0.01, 1, 0.01, 1, 'M')],
   '1.10 - 0.0591/2*log(zn/cu)', 'Cell emf', 1.13, 0.005, {'zn': 0.1, 'cu': 1},
   'E = E° − (0.0591/2) log([Zn²⁺]/[Cu²⁺]) = 1.10 − 0.0296 × (−1) ≈ 1.13 V.', hint='Make [Zn²⁺] smaller than [Cu²⁺].', unit='V')
ch('puc2-chemistry-electrochemistry', 't4', 'Plate 1.27 g of copper',
   'Electrolyse CuSO₄. Choose the current and time to deposit 1.27 g of copper (M = 63.5, n = 2, F = 96 500 C).',
   [S('I', 'Current', 0.5, 10, 0.5, 1, 'A'), S('t', 'Time', 5, 120, 1, 30, 'min')],
   '63.5*I*t*60/(2*96500)', 'Copper deposited', 1.27, 0.02, {'I': 2, 't': 32},
   'm = M I t / (nF): 1.27 g is 0.02 mol, needing 0.04 F = 3860 C. 2 A for 32 min gives 3840 C ≈ 1.26 g.', hint='Charge Q = I t (t in seconds).', unit='g')
ch('puc2-chemistry-the-d-and-f-block-elements', 't4', '5.92 BM',
   'A transition metal ion has a spin-only magnetic moment of 5.92 BM. How many unpaired electrons does it have?',
   [S('n', 'Unpaired electrons', 0, 7, 1, 1)], 'sqrt(n*(n + 2))', 'Magnetic moment', 5.92, 0.02, {'n': 5},
   'μ = √(n(n + 2)) = √35 ≈ 5.92 BM for n = 5, as in Mn²⁺ or Fe³⁺ (3d⁵).', hint='μ = √(n(n + 2)) BM.', unit='BM', mode='roll_call')

# ================================================================== MATHS
ch('puc1-maths-straight-lines', 't4', 'Through two points',
   'Set the slope m and intercept c of y = mx + c so the line passes through (1, 2) and (5, 8).',
   [S('m', 'Slope m', -3, 3, 0.5, 1), S('c', 'Intercept c', -5, 5, 0.5, 0)],
   'abs(m + c - 2) + abs(5*m + c - 8)', 'Total miss', 0, 0.01, {'m': 1.5, 'c': 0.5},
   'm = (8 − 2)/(5 − 1) = 1.5; then 2 = 1.5 + c gives c = 0.5.', hint='Slope = rise / run.',
   kind='function_plot', fns=[{'fn': 'm*x + c', 'label': 'y = mx + c', 'color': 'yellow'}], x=[-1, 7], y=[-2, 12])
ch('puc1-maths-trigonometric-functions', 't3', 'Shape the wave',
   'Make y = A sin(Bx) have amplitude 2 and period π.',
   [S('A', 'A', 0.5, 4, 0.5, 1), S('B', 'B', 0.5, 4, 0.5, 1)], 'abs(A - 2) + abs(2*pi/B - pi)', 'Total miss', 0, 0.01, {'A': 2, 'B': 2},
   'Amplitude = |A| = 2; period = 2π/B = π, so B = 2.', hint='Period of sin(Bx) is 2π/B.',
   kind='function_plot', fns=[{'fn': 'A*sin(B*x)', 'color': 'yellow'}], x=[0, 7], y=[-4, 4])
ch('puc1-maths-trigonometric-functions', 't1', '5π/6 radians',
   'Turn the angle to exactly 5π/6 radians.',
   [S('theta', 'θ', 0, 360, 1, 40, '°')], 'theta*pi/180', 'Angle', 2.618, 0.005, {'theta': 150},
   '5π/6 rad × 180°/π = 150°.', hint='π rad = 180°.', unit='rad', kind='unit_circle')
ch('puc1-maths-complex-numbers-and-quadratic-equations', 't3', 'Modulus 5, argument 53.13°',
   'Choose z = a + ib with |z| = 5 and argument 53.13° (first quadrant).',
   [S('a', 'Re z = a', -5, 5, 1, 1), S('b', 'Im z = b', -5, 5, 1, 1)], 'abs(sqrt(a^2 + b^2) - 5) + abs(atan(b/a)*180/pi - 53.13)', 'Total miss', 0, 0.05, {'a': 3, 'b': 4},
   '|3 + 4i| = √(9 + 16) = 5 and tan⁻¹(4/3) = 53.13°.', hint='A 3-4-5 triangle.', kind='vectors', vectors=[['a', 'b']], x=[-6, 6], y=[-6, 6], xLabel='Re', yLabel='Im')
ch('puc1-maths-sequences-and-series', 't4', 'Sum to 255',
   'Choose a, r and n so the G.P. a + ar + ar² + … (n terms) adds up to 255.',
   [S('a', 'First term a', 1, 5, 1, 1), S('r', 'Ratio r', 2, 4, 1, 2), S('n', 'Terms n', 1, 10, 1, 4)],
   'a*(r^n - 1)/(r - 1)', 'Sum', 255, 0.5, {'a': 1, 'r': 2, 'n': 8},
   'Sₙ = a(rⁿ − 1)/(r − 1) = 2⁸ − 1 = 255 (also a = 3, r = 4, n = 4).', hint='Sₙ = a(rⁿ − 1)/(r − 1).')
ch('puc1-maths-permutations-and-combinations', 't4', '66 handshakes',
   'Everyone at a meeting shakes hands once with everyone else. There were 66 handshakes. How many people came?',
   [S('n', 'People', 2, 30, 1, 5)], 'n*(n - 1)/2', 'Handshakes', 66, 0.1, {'n': 12},
   'Handshakes = ⁿC₂ = n(n − 1)/2 = 66, so n(n − 1) = 132 = 12 × 11.', hint='Each handshake is a choice of 2 people.', mode='roll_call')
ch('puc1-maths-limits-and-derivatives', 't4', 'Slope six',
   'Slide the point along y = x² until the tangent there has slope 6.',
   [S('a', 'Point x = a', -4, 4, 0.5, 1)], '2*a', 'Tangent slope', 6, 0.01, {'a': 3},
   'From first principles d(x²)/dx = 2x; 2a = 6 at a = 3, the point (3, 9).', hint='The derivative of x² is 2x.',
   kind='function_plot', fns=[{'fn': 'x^2', 'color': 'yellow'}, {'fn': '2*a*(x - a) + a^2', 'label': 'tangent', 'color': 'green'}], x=[-5, 5], y=[-5, 25])
ch('puc1-maths-conic-sections', 't2', 'Draw the circle',
   'Draw the circle with centre (2, −1) that passes through (5, 3). Choose h, k and r.',
   [S('h', 'Centre h', -4, 6, 1, 0), S('k', 'Centre k', -4, 4, 1, 0), S('r', 'Radius r', 1, 8, 1, 3)],
   'abs(h - 2) + abs(k + 1) + abs(sqrt((5 - h)^2 + (3 - k)^2) - r)', 'Total miss', 0, 0.01, {'h': 2, 'k': -1, 'r': 5},
   'r = distance from (2, −1) to (5, 3) = √(9 + 16) = 5: (x − 2)² + (y + 1)² = 25.', hint='The radius is the distance to the point.',
   kind='function_plot', fns=[{'fn': 'k + sqrt(r^2 - (x - h)^2)', 'color': 'yellow'}, {'fn': 'k - sqrt(r^2 - (x - h)^2)', 'color': 'yellow'}], x=[-6, 10], y=[-8, 8])
ch('puc1-maths-statistics', 't4', 'Variance of five',
   'The data are 2, 4, x and 8. Choose x so the variance is exactly 5.',
   [S('xv', 'x', 0, 12, 1, 9)], '(4 + 16 + xv^2 + 64)/4 - ((14 + xv)/4)^2', 'Variance', 5, 0.01, {'xv': 6},
   'With x = 6 the mean is 5 and Σx²/n = 120/4 = 30, so σ² = 30 − 25 = 5.', hint='σ² = Σx²/n − (mean)².',
   kind='bar_chart', data={'2': 2, '4': 4, 'x': 'xv', '8': 8})
ch('puc2-maths-application-of-derivatives', 't3', 'The biggest box',
   'Cut equal squares of side x from the corners of an 18 cm × 18 cm sheet and fold up a box. Find the x that gives the largest volume.',
   [S('xc', 'Cut x', 0.5, 8.5, 0.5, 1, 'cm')], 'xc*(18 - 2*xc)^2', 'Volume', 432, 1, {'xc': 3},
   'V = x(18 − 2x)²; V′ = (18 − 2x)(18 − 6x) = 0 gives x = 3 (x = 9 makes no box). V = 3 × 12² = 432 cm³.', hint='Set dV/dx = 0.', unit='cm³',
   kind='bar_chart', data={'base side': '18 - 2*xc', 'height': 'xc'})
ch('puc2-maths-application-of-derivatives', 't5', 'Most field for the fence',
   'A farmer has 40 m of fence for three sides of a rectangle; a wall is the fourth. Choose the width x for the largest area.',
   [S('w', 'Width x', 1, 19, 0.5, 5, 'm')], 'w*(40 - 2*w)', 'Area', 200, 0.5, {'w': 10},
   'A = x(40 − 2x); A′ = 40 − 4x = 0 at x = 10 m, A = 200 m².', hint='Maximise A(x) = x(40 − 2x).', unit='m²',
   kind='bar_chart', data={'width': 'w', 'length': '40 - 2*w'})
ch('puc2-maths-integrals', 't5', 'Area of 12',
   'Choose the upper limit a so that ∫₀ᵃ (2x + 1) dx = 12.',
   [S('a', 'Upper limit a', 0, 6, 0.5, 1)], 'a^2 + a', 'Integral', 12, 0.01, {'a': 3},
   '∫₀ᵃ (2x + 1) dx = a² + a = 12, so a = 3 (a = −4 is outside 0..6).', hint='Antiderivative: x² + x.',
   kind='function_plot', fns=[{'fn': '2*x + 1', 'color': 'yellow'}], x=[0, 6], y=[0, 14])
ch('puc2-maths-application-of-integrals', 't4', 'Area between curve and line',
   'Choose k so the region between y = x² and y = kx has area 36.',
   [S('k', 'k', 1, 8, 0.5, 2)], 'k^3/6', 'Area', 36, 0.1, {'k': 6},
   'They meet at x = 0 and x = k; area = ∫₀ᵏ (kx − x²) dx = k³/6 = 36 gives k = 6.', hint='Find where they meet first.',
   kind='function_plot', fns=[{'fn': 'x^2', 'color': 'yellow'}, {'fn': 'k*x', 'color': 'green'}], x=[0, 8], y=[0, 64])
ch('puc2-maths-determinants', 't1', 'Make it singular',
   'For the matrix [[2, a], [3, b]], choose a and b so its determinant is 0 and its trace (2 + b) is 8.',
   [S('a', 'a', 1, 8, 1, 1), S('b', 'b', 1, 8, 1, 1)], 'abs(2*b - 3*a) + abs(2 + b - 8)', 'Total miss', 0, 0.01, {'a': 4, 'b': 6},
   'Trace 8 gives b = 6; det = 2b − 3a = 12 − 3a = 0 gives a = 4.', hint='det [[p, q], [r, s]] = ps − qr.')
ch('puc2-maths-vector-algebra', 't4', 'Perpendicular',
   'Make a = 2i + k j perpendicular to b = 3i − 6j.',
   [S('k', 'k', -3, 3, 0.5, -1)], '2*3 + k*(-6)', 'a · b', 0, 0.01, {'k': 1},
   'a · b = 6 − 6k = 0 gives k = 1.', hint='Perpendicular vectors have a zero dot product.', kind='vectors', vectors=[[2, 'k'], [3, -6]], x=[-4, 6], y=[-7, 4])
ch('puc2-maths-linear-programming', 't3', 'Best corner',
   'Maximise Z = 3x + 2y subject to x + y ≤ 4, x + 3y ≤ 6, x, y ≥ 0. Breaking a constraint costs 100 a unit. Find the best point.',
   [S('xv', 'x', 0, 6, 0.5, 1), S('yv', 'y', 0, 4, 0.5, 1)],
   '3*xv + 2*yv - 50*(abs(xv + yv - 4) + xv + yv - 4) - 50*(abs(xv + 3*yv - 6) + xv + 3*yv - 6)', 'Z (with penalty)', 12, 0.01, {'xv': 4, 'yv': 0},
   'Corner points: (0, 0) → 0, (4, 0) → 12, (3, 1) → 11, (0, 2) → 4. The maximum is 12 at (4, 0).', hint='Test every corner point of the feasible region.',
   mode='team', kind='function_plot', fns=[{'fn': '4 - x', 'label': 'x + y = 4', 'color': 'yellow'}, {'fn': '(6 - x)/3', 'label': 'x + 3y = 6', 'color': 'green'}], x=[0, 6], y=[0, 4])
ch('puc2-maths-continuity-and-differentiability', 't1', 'Join the pieces',
   'f(x) = kx + 1 for x ≤ 2 and 3x − 1 for x > 2. Choose k so f is continuous at x = 2.',
   [S('k', 'k', -3, 5, 0.5, 0)], '2*k + 1 - (3*2 - 1)', 'Jump at x = 2', 0, 0.01, {'k': 2},
   'Left limit 2k + 1 must equal right limit 5, so k = 2.', hint='Left-hand limit = right-hand limit = f(2).',
   kind='function_plot', fns=[{'fn': 'k*x + 1', 'label': 'kx + 1', 'color': 'yellow'}, {'fn': '3*x - 1', 'label': '3x − 1', 'color': 'green'}], x=[-1, 5], y=[-4, 14])
ch('puc2-maths-differential-equations', 't3', 'Double in 3 hours',
   'Bacteria grow as dN/dt = kN. Choose k so the population doubles in 3 hours.',
   [S('k', 'k', 0.05, 0.5, 0.001, 0.1, 'per hour')], 'exp(3*k)', 'N(3) / N(0)', 2, 0.01, {'k': 0.231},
   'N = N₀eᵏᵗ; e³ᵏ = 2 gives k = ln 2 / 3 ≈ 0.231 per hour.', hint='Separate the variables: ln N = kt + C.',
   kind='function_plot', fns=[{'fn': '100*exp(k*x)', 'label': 'N(t)', 'color': 'yellow'}], x=[0, 10], y=[0, 1000], xLabel='t (h)', yLabel='N')

# ================================================================== ACCOUNTANCY
ch('puc1-accountancy-depreciation-provisions-and-reserves', 't2', '₹18,000 a year',
   'A machine costs ₹1,00,000. Choose its scrap value and useful life so straight-line depreciation is ₹18,000 a year.',
   [S('Sv', 'Scrap value', 0, 30000, 1000, 0, '₹'), S('n', 'Life', 2, 15, 1, 10, 'years')], '(100000 - Sv)/n', 'Annual depreciation', 18000, 1, {'Sv': 10000, 'n': 5},
   'SLM: (Cost − Scrap) / Life = (1,00,000 − 10,000) / 5 = ₹18,000.', hint='Depreciation = (cost − scrap value) / useful life.', unit='₹')
ch('puc1-accountancy-depreciation-provisions-and-reserves', 't3', 'Down to ₹81,000',
   'A machine costs ₹1,00,000. At what written-down-value rate is its book value ₹81,000 after 2 years?',
   [S('r', 'Rate', 5, 40, 1, 20, '%')], '100000*(1 - r/100)^2', 'Book value after 2 years', 81000, 50, {'r': 10},
   'WDV: 1,00,000 × 0.9 × 0.9 = ₹81,000, so r = 10%.', hint='Each year the value is multiplied by (1 − r/100).', unit='₹')
ch('puc1-accountancy-bank-reconciliation-statement', 't4', 'Find the unpresented cheques',
   'Cash book balance ₹25,000. Cheques deposited but not yet credited ₹4,000; bank charges ₹500 not in the cash book. The pass book shows ₹28,500. How much in cheques issued is not yet presented?',
   [S('C', 'Unpresented cheques', 0, 20000, 500, 2000, '₹')], '25000 + C - 4000 - 500', 'Pass book balance', 28500, 1, {'C': 8000},
   'Start from the cash book: + unpresented cheques − uncredited cheques − bank charges. 25,000 + C − 4,500 = 28,500 gives C = ₹8,000.', unit='₹')
ch('puc1-accountancy-financial-statements-i', 't2', 'A 25% gross profit',
   'Sales ₹2,00,000, opening stock ₹30,000, purchases ₹1,40,000. What closing stock gives a gross profit of 25% on sales?',
   [S('CS', 'Closing stock', 0, 60000, 1000, 10000, '₹')], '200000 - (30000 + 140000 - CS)', 'Gross profit', 50000, 1, {'CS': 20000},
   'GP = 25% of 2,00,000 = 50,000, so cost of goods sold = 1,50,000 = 30,000 + 1,40,000 − CS, CS = ₹20,000.', hint='Cost of goods sold = opening stock + purchases − closing stock.', unit='₹')
ch('puc1-accountancy-recording-of-transactions-i', 't2', 'Balance the equation',
   'Assets are ₹5,00,000 and capital is ₹3,20,000. Set the liabilities so the accounting equation balances.',
   [S('Lb', 'Liabilities', 0, 400000, 10000, 100000, '₹')], '500000 - (Lb + 320000)', 'Assets − (liabilities + capital)', 0, 1, {'Lb': 180000},
   'Assets = Liabilities + Capital: 5,00,000 = L + 3,20,000, so L = ₹1,80,000.', hint='A = L + C.', unit='₹',
   kind='bar_chart', data={'Assets': 500000, 'Liabilities': 'Lb', 'Capital': 320000})
ch('puc1-accountancy-trial-balance-and-rectification-of-errors', 't5', 'Suspense account',
   'The trial balance totals are debit ₹1,52,000 and credit ₹1,49,500. What amount goes to the suspense account, on the credit side, to make it agree?',
   [S('Sa', 'Suspense (credit)', 0, 10000, 100, 0, '₹')], '152000 - (149500 + Sa)', 'Debit − credit', 0, 1, {'Sa': 2500},
   'The credit side is short by ₹2,500, so the suspense account shows ₹2,500 on the credit side until the errors are found.', unit='₹', mode='roll_call')
ch('puc1-accountancy-financial-statements-ii', 't4', 'Provision for doubtful debts',
   'Debtors are ₹80,000. Choose further bad debts to write off and the provision rate so the provision for doubtful debts is ₹3,900.',
   [S('p', 'Provision rate', 1, 10, 0.5, 2, '%'), S('Bd', 'Further bad debts', 0, 5000, 500, 0, '₹')], 'p/100*(80000 - Bd)', 'Provision', 3900, 1, {'p': 5, 'Bd': 2000},
   'Write off ₹2,000 first, then 5% of the remaining ₹78,000 = ₹3,900.', hint='The provision is on debtors after writing off bad debts.', unit='₹')
ch('puc2-accountancy-accounting-ratios', 't2', 'Current 2:1, quick 1:1',
   'Inventory is ₹1,50,000. Choose current assets and current liabilities so the current ratio is 2:1 and the quick ratio is 1:1.',
   [S('CA', 'Current assets', 100000, 600000, 10000, 300000, '₹'), S('CL', 'Current liabilities', 50000, 300000, 10000, 200000, '₹')],
   'abs(CA/CL - 2) + abs((CA - 150000)/CL - 1)', 'Total miss', 0, 0.01, {'CA': 300000, 'CL': 150000},
   'CA = 2 CL and CA − 1,50,000 = CL, so CL = ₹1,50,000 and CA = ₹3,00,000.', hint='Quick assets = current assets − inventory.')
ch('puc2-accountancy-accounting-ratios', 't5', 'A 20% gross profit ratio',
   'Goods are sold at cost plus a mark-up. What mark-up on cost gives a gross profit ratio of 20% on sales?',
   [S('mk', 'Mark-up on cost', 5, 60, 1, 10, '%')], '100*mk/(100 + mk)', 'Gross profit ratio', 20, 0.05, {'mk': 25},
   'On cost 100, sales are 100 + m and GP is m: m/(100 + m) = 20% gives m = 25%.', hint='GP ratio = GP / sales, not GP / cost.', unit='%')
ch('puc2-accountancy-accounting-for-partnership-basic-concepts', 't3', "A's ₹70,000",
   'Profit ₹1,20,000. A and B (capitals ₹3,00,000 and ₹2,00,000) get 10% interest on capital and share the rest equally after a salary to A. What salary makes A\'s total ₹70,000?',
   [S('Sal', "A's salary", 0, 40000, 1000, 20000, '₹')], '30000 + Sal + (120000 - 50000 - Sal)/2', "A's total", 70000, 1, {'Sal': 10000},
   'Interest: A 30,000, B 20,000. A gets 30,000 + S + (70,000 − S)/2 = 70,000, so S = ₹10,000.', hint='Interest on capital and salary come before the profit is shared.', unit='₹')
ch('puc2-accountancy-reconstitution-of-a-partnership-firm-admission-of-a-partner', 't2', 'Goodwill of ₹30,000',
   'Average profit ₹50,000, capital employed ₹4,00,000. Choose the normal rate of return and the years of purchase so goodwill (super profit method) is ₹30,000.',
   [S('r', 'Normal rate', 5, 15, 0.5, 8, '%'), S('n', 'Years of purchase', 1, 6, 1, 2)], '(50000 - 400000*r/100)*n', 'Goodwill', 30000, 1, {'r': 10, 'n': 3},
   'Normal profit at 10% = 40,000; super profit 10,000; × 3 years = ₹30,000.', hint='Goodwill = (average profit − normal profit) × years.', unit='₹')
ch('puc2-accountancy-cash-flow-statement', 't3', 'Operating cash ₹1,20,000',
   'Net profit ₹1,00,000, depreciation ₹20,000, creditors up by ₹15,000. By how much did debtors rise if cash from operations is ₹1,20,000?',
   [S('Dr', 'Increase in debtors', 0, 50000, 1000, 30000, '₹')], '100000 + 20000 - Dr + 15000', 'Cash from operating activities', 120000, 1, {'Dr': 15000},
   'Indirect method: 1,00,000 + 20,000 + 15,000 − D = 1,20,000, so D = ₹15,000.', hint='Add back depreciation; a rise in debtors is deducted.', unit='₹')
ch('puc2-accountancy-analysis-of-financial-statements', 't5', 'Common size: 60%',
   'Revenue from operations is ₹4,00,000. What cost of goods sold shows as 60% in a common-size statement?',
   [S('C', 'Cost of goods sold', 100000, 400000, 10000, 200000, '₹')], 'C/400000*100', 'Common-size %', 60, 0.1, {'C': 240000},
   'Each item as a % of revenue: 2,40,000 / 4,00,000 = 60%.', unit='%', mode='roll_call')

# ================================================================== ECONOMICS
DS = [{'fn': '(400 - x)/10', 'label': 'demand', 'color': 'yellow'}, {'fn': '(x - 50)/15', 'label': 'supply', 'color': 'green'}, {'fn': 'p', 'label': 'price', 'color': 'white'}]
ch('puc2-economics-market-equilibrium', 't2', 'Festival demand',
   'Supply is qS = 50 + 15p. In the festival season demand rises to qD = 400 − 10p. Find the new equilibrium price.',
   [S('p', 'Price', 0, 30, 0.5, 10, '₹')], '(400 - 10*p) - (50 + 15*p)', 'Excess demand', 0, 0.1, {'p': 14},
   '400 − 10p = 50 + 15p gives 25p = 350, p = ₹14 (it was ₹10 before the rise).', hint='Set qD = qS.', unit='units',
   kind='function_plot', fns=DS, x=[0, 400], y=[0, 40], xLabel='quantity', yLabel='price')
ch('puc2-economics-market-equilibrium', 't5', 'A shortage of 100',
   'Demand qD = 300 − 10p and supply qS = 50 + 15p. At what price ceiling is the shortage exactly 100 units?',
   [S('pc', 'Price ceiling', 0, 10, 0.5, 9, '₹')], '(300 - 10*pc) - (50 + 15*pc)', 'Shortage', 100, 0.5, {'pc': 6},
   'Shortage = qD − qS = 250 − 25p = 100 gives p = ₹6 (below the equilibrium ₹10).', hint='Shortage = qD − qS at the ceiling.', unit='units')
ch('puc2-economics-theory-of-consumer-behaviour', 't4', 'The best bundle',
   'Income ₹100, p₁ = ₹5, p₂ = ₹10, utility U = x₁x₂ (so MRS = x₂/x₁). Choose the optimal bundle.',
   [S('x1', 'Good 1', 1, 20, 1, 4), S('x2', 'Good 2', 0, 10, 1, 4)], 'abs(5*x1 + 10*x2 - 100) + 10*abs(x2/x1 - 0.5)', 'Distance from optimum', 0, 0.01, {'x1': 10, 'x2': 5},
   'Optimum: on the budget line and MRS = p₁/p₂ = 0.5, so x₂ = x₁/2 and 5x₁ + 5x₁ = 100: (10, 5).', hint='Spend all income, and set MRS = p₁ / p₂.',
   kind='function_plot', fns=[{'fn': '(100 - 5*x)/10', 'label': 'budget line', 'color': 'yellow'}, {'fn': 'x1*x2/x', 'label': 'indifference curve', 'color': 'green'}], x=[0, 20], y=[0, 10], xLabel='good 1', yLabel='good 2')
ch('puc2-economics-theory-of-consumer-behaviour', 't6', 'Elasticity of 1.5',
   'Price falls from ₹10 to ₹8 and quantity demanded rises from 100 units. To what quantity must it rise for price elasticity of demand to be 1.5 (in magnitude)?',
   [S('q', 'New quantity', 100, 200, 5, 110, 'units')], '((q - 100)/100)/((10 - 8)/10)', '|eD|', 1.5, 0.01, {'q': 130},
   'eD = (%Δq)/(%Δp): price falls 20%, so quantity must rise 30%, to 130.', hint='Percentage method: (Δq/q) / (Δp/p).', mode='roll_call')
ch('puc2-economics-production-and-costs', 't4', 'Average cost ₹30',
   'TFC = ₹200 and AVC = ₹20 at every output. At what output is the average cost ₹30?',
   [S('q', 'Output', 1, 50, 1, 5, 'units')], '(200 + 20*q)/q', 'Average cost', 30, 0.1, {'q': 20},
   'AC = AFC + AVC = 200/q + 20 = 30 gives q = 20.', hint='AC = AFC + AVC; AFC falls as output rises.', unit='₹',
   kind='function_plot', fns=[{'fn': '(200 + 20*x)/x', 'label': 'AC', 'color': 'yellow'}, {'fn': '20 + 0*x', 'label': 'AVC', 'color': 'green'}], x=[1, 50], y=[0, 100], xLabel='output', yLabel='₹')
ch('puc2-economics-the-theory-of-the-firm-under-perfect-competition', 't3', 'Profit-maximising output',
   'A price-taking firm has TC = q² + 10q + 50, so MC = 2q + 10. The market price is ₹50. Choose its output.',
   [S('q', 'Output', 0, 40, 1, 10, 'units')], '2*q + 10', 'Marginal cost', 50, 0.1, {'q': 20},
   'Profit is largest where p = MC (and MC is rising): 2q + 10 = 50, q = 20.', hint='Under perfect competition MR = price.', unit='₹',
   kind='function_plot', fns=[{'fn': '2*x + 10', 'label': 'MC', 'color': 'yellow'}, {'fn': '50 + 0*x', 'label': 'price', 'color': 'green'}], x=[0, 40], y=[0, 100], xLabel='output', yLabel='₹')
ch('puc2-economics-the-theory-of-the-firm-under-perfect-competition', 't6', 'Supply elasticity of 2',
   'Price rises from ₹10 to ₹12; quantity supplied was 200. To what quantity must supply rise for an elasticity of 2?',
   [S('q', 'New quantity', 200, 400, 10, 220, 'units')], '((q - 200)/200)/((12 - 10)/10)', 'eS', 2, 0.01, {'q': 280},
   'eS = (%Δq)/(%Δp) = 2 with a 20% price rise needs a 40% rise in quantity: 280 units.', hint='eS = (Δq/q) / (Δp/p).')
ch('puc2-economics-determination-of-income-and-employment', 't4', 'Multiply by five',
   'Investment rises by ₹100 crore. Choose the MPC so equilibrium income rises by ₹500 crore.',
   [S('c', 'MPC', 0.1, 0.95, 0.05, 0.5)], '100/(1 - c)', 'Rise in income', 500, 1, {'c': 0.8},
   'Multiplier k = 1/(1 − MPC) = 500/100 = 5, so MPC = 0.8.', hint='ΔY = k × ΔI, k = 1/(1 − MPC).', unit='₹ crore',
   kind='function_plot', fns=[{'fn': '100 + c*x', 'label': 'AD', 'color': 'yellow'}, {'fn': 'x', 'label': 'Y = AD', 'color': 'white'}], x=[0, 1000], y=[0, 1000], xLabel='income', yLabel='AD')
ch('puc2-economics-national-income-accounting', 't3', 'GDP of ₹900 crore',
   'C = 500, I = 150, G = 200 and exports = 100 (₹ crore). What level of imports gives GDP at market price of 900?',
   [S('M', 'Imports', 0, 200, 10, 120, '₹ cr')], '500 + 150 + 200 + (100 - M)', 'GDP (MP)', 900, 0.5, {'M': 50},
   'GDP = C + I + G + (X − M) = 850 + 100 − M = 900, so M = 50.', hint='Expenditure method: C + I + G + net exports.', unit='₹ cr',
   kind='bar_chart', data={'C': 500, 'I': 150, 'G': 200, 'X': 100, 'M': 'M'})
ch('puc2-economics-money-and-banking', 't3', 'Five-fold deposits',
   'A new deposit of ₹1,000 lets banks create total deposits of ₹5,000. Set the cash reserve ratio.',
   [S('r', 'CRR', 5, 50, 1, 10, '%')], '1000*100/r', 'Total deposits', 5000, 1, {'r': 20},
   'Money multiplier = 1/CRR = 5, so CRR = 20%.', hint='Total deposits = initial deposit / CRR.', unit='₹')
ch('puc2-economics-government-budget-and-the-economy', 't5', 'Primary deficit of 250',
   'Revenue receipts 1,200, non-debt capital receipts 100, interest payments 150 (₹ crore). What total expenditure gives a primary deficit of 250?',
   [S('E', 'Total expenditure', 1000, 2500, 50, 1500, '₹ cr')], 'E - (1200 + 100) - 150', 'Primary deficit', 250, 0.5, {'E': 1700},
   'Fiscal deficit = E − 1,300; primary deficit = fiscal deficit − interest = E − 1,450 = 250, so E = 1,700.', hint='Primary deficit = fiscal deficit − interest payments.', unit='₹ cr')
ch('puc1-economics-measures-of-central-tendency', 't1', 'Mean of 62',
   'Four students scored 48, 65, 57 and 70. What must the fifth score so the class mean is 62?',
   [S('m5', 'Fifth score', 0, 100, 1, 40)], '(48 + 65 + 57 + 70 + m5)/5', 'Mean', 62, 0.1, {'m5': 70},
   'Total needed 62 × 5 = 310; 310 − 240 = 70.', hint='Mean × number of items = total.', mode='roll_call',
   kind='bar_chart', data={'1': 48, '2': 65, '3': 57, '4': 70, '5': 'm5'})
ch('puc1-economics-correlation', 't5', 'Rank correlation 0.6',
   'Five pairs are ranked. What Σd² gives Spearman\'s rank correlation of 0.6?',
   [S('D', 'Σd²', 0, 40, 2, 20)], '1 - 6*D/(5*(25 - 1))', 'rs', 0.6, 0.001, {'D': 8},
   'rs = 1 − 6Σd²/(n(n² − 1)) = 1 − 6D/120 = 0.6 gives D = 8.', hint='n(n² − 1) = 5 × 24 = 120.')
ch('puc1-economics-index-numbers', 't3', 'Laspeyres index 120',
   'Base prices ₹10 and ₹20, base quantities 5 and 2. The first good now costs ₹12. What price of the second good makes the Laspeyres index 120?',
   [S('p2', 'New price of good 2', 10, 40, 1, 20, '₹')], '(12*5 + p2*2)/(10*5 + 20*2)*100', 'Laspeyres index', 120, 0.1, {'p2': 24},
   'Σp₁q₀ / Σp₀q₀ × 100 = (60 + 2p) / 90 × 100 = 120 gives p = ₹24.', hint='Laspeyres uses base-year quantities.')
ch('puc1-economics-presentation-of-data', 't2', 'A 126° slice',
   'A family spends ₹20,000 a month. How much on food makes the food slice of a pie diagram 126°?',
   [S('F', 'Food', 1000, 15000, 500, 5000, '₹')], 'F/20000*360', 'Angle of the food slice', 126, 0.5, {'F': 7000},
   'Angle = share × 360°: 7,000/20,000 × 360 = 126°.', unit='°', kind='pie_chart', data={'Food': 'F', 'Other': '20000 - F'})

# ================================================================== STATISTICS
ch('puc1-statistics-measures-of-dispersion', 't5', 'CV of 12%',
   'Choose the mean and standard deviation of a batch of bulbs\' lives (hundreds of hours) so the coefficient of variation is 12%.',
   [S('m', 'Mean', 20, 100, 5, 50), S('sd', 'SD', 1, 20, 0.5, 10)], 'sd/m*100', 'CV', 12, 0.05, {'m': 50, 'sd': 6},
   'CV = σ / mean × 100 = 6/50 × 100 = 12%.', hint='CV = σ / x̄ × 100.', unit='%')
ch('puc1-statistics-measures-of-central-tendency', 't2', 'Combined mean 65',
   'Section A: 40 students, mean 60. Section B has mean 70. How many students in B make the combined mean 65?',
   [S('n2', 'Students in B', 10, 100, 5, 20)], '(40*60 + n2*70)/(40 + n2)', 'Combined mean', 65, 0.05, {'n2': 40},
   'x̄ = (n₁x̄₁ + n₂x̄₂)/(n₁ + n₂): 65 lies midway, so the groups are equal: n₂ = 40.', hint='Combined mean = total marks / total students.')
ch('puc1-statistics-measures-of-central-tendency', 't5', 'Geometric mean 8',
   'Choose x so the geometric mean of 4 and x is 8.',
   [S('xg', 'x', 1, 30, 1, 9)], 'sqrt(4*xg)', 'GM', 8, 0.01, {'xg': 16},
   'GM = √(4x) = 8 gives 4x = 64, x = 16.', mode='roll_call')
ch('puc1-statistics-probability', 't4', 'Conditional probability 0.4',
   'P(A ∩ B) = 0.12. Choose P(B) so that P(A | B) = 0.4.',
   [S('pb', 'P(B)', 0.1, 1, 0.05, 0.6)], '0.12/pb', 'P(A | B)', 0.4, 0.001, {'pb': 0.3},
   'P(A | B) = P(A ∩ B) / P(B) = 0.12 / 0.3 = 0.4.', kind='pie_chart', data={'B': 'pb', 'not B': '1 - pb'})
ch('puc1-statistics-correlation-and-regression', 't4', 'Draw the regression line',
   'x̄ = 10, ȳ = 25, r = 0.6, σx = 4, σy = 10. Set the line of regression of y on x, y = a + bx.',
   [S('a', 'Intercept a', -10, 30, 1, 0), S('b', 'Slope b', 0, 3, 0.25, 1)], 'abs(a + b*10 - 25) + abs(b - 1.5)', 'Total miss', 0, 0.01, {'a': 10, 'b': 1.5},
   'b_yx = r σy/σx = 0.6 × 10/4 = 1.5; the line passes through the means: a = 25 − 1.5 × 10 = 10.', hint='The regression line passes through (x̄, ȳ).',
   kind='function_plot', fns=[{'fn': 'a + b*x', 'color': 'yellow'}], x=[0, 20], y=[0, 50])
ch('puc1-statistics-moments-skewness-and-kurtosis', 't3', 'Skewness 0.5',
   'Mean 45 and SD 10. What mode gives Karl Pearson\'s coefficient of skewness 0.5?',
   [S('mo', 'Mode', 30, 60, 1, 45)], '(45 - mo)/10', 'Skewness', 0.5, 0.001, {'mo': 40},
   'Sk = (mean − mode) / σ = (45 − 40)/10 = 0.5: positively skewed.', hint='Sk = (x̄ − Z) / σ.')
ch('puc1-statistics-theory-of-attributes', 't5', "Yule's Q of 0.6",
   '(AB) = 40, (ab) = 30, (Ab) = 10. Choose (aB) so Yule\'s coefficient of association is 0.6.',
   [S('aB', '(aB)', 5, 100, 5, 60)], '(40*30 - 10*aB)/(40*30 + 10*aB)', 'Q', 0.6, 0.005, {'aB': 30},
   'Q = (1200 − 10x)/(1200 + 10x) = 0.6 gives 480 = 16x, x = 30.', hint='Q = ((AB)(ab) − (Ab)(aB)) / ((AB)(ab) + (Ab)(aB)).')
ch('puc2-statistics-theoretical-distributions', 't1', 'Mean 6, variance 2.4',
   'Choose n and p of a binomial distribution with mean 6 and variance 2.4.',
   [S('n', 'n', 1, 30, 1, 20), S('p', 'p', 0.05, 0.95, 0.05, 0.5)], 'abs(n*p - 6) + abs(n*p*(1 - p) - 2.4)', 'Total miss', 0, 0.01, {'n': 10, 'p': 0.6},
   'q = variance/mean = 2.4/6 = 0.4, p = 0.6, n = 6/0.6 = 10.', hint='Mean np, variance npq: divide them.')
ch('puc2-statistics-theoretical-distributions', 't5', 'z = 1.5',
   'Marks are normal with mean 60 and SD 8. What score has standard normal variate z = 1.5?',
   [S('xs', 'Score', 30, 100, 1, 60)], '(xs - 60)/8', 'z', 1.5, 0.01, {'xs': 72},
   'z = (x − μ)/σ: x = 60 + 1.5 × 8 = 72.', mode='roll_call',
   kind='function_plot', fns=[{'fn': 'exp(-(x - 60)^2/128)', 'label': 'normal curve', 'color': 'yellow'}], x=[30, 90], y=[0, 1.1])
ch('puc2-statistics-theoretical-distributions', 't2', 'No calls at all',
   'Calls arrive as a Poisson variable. Choose the mean m so the chance of no call in a minute is 0.1353.',
   [S('m', 'Mean m', 0.5, 5, 0.1, 1)], 'exp(-m)', 'P(X = 0)', 0.1353, 0.001, {'m': 2},
   'P(0) = e⁻ᵐ = 0.1353 = e⁻², so m = 2.', hint='P(X = 0) = e⁻ᵐ.')
ch('puc2-statistics-time-series-analysis', 't4', 'Fit the trend line',
   'Five years, x coded −2…2: Σy = 250, Σxy = 60, Σx² = 10. Set the least-squares trend y = a + bx.',
   [S('a', 'a', 0, 100, 1, 40), S('b', 'b', 0, 10, 0.5, 2)], 'abs(5*a - 250) + abs(10*b - 60)', 'Total miss', 0, 0.01, {'a': 50, 'b': 6},
   'With Σx = 0 the normal equations give a = Σy/n = 50 and b = Σxy/Σx² = 6.', hint='Σx = 0, so a = Σy/n, b = Σxy/Σx².',
   kind='function_plot', fns=[{'fn': 'a + b*x', 'label': 'trend', 'color': 'yellow'}], x=[-3, 3], y=[0, 100])
ch('puc2-statistics-index-numbers', 't3', "Fisher's index 130",
   "Laspeyres' index is 125. What Paasche's index makes Fisher's ideal index 130?",
   [S('P', "Paasche's index", 100, 160, 0.1, 120)], 'sqrt(125*P)', "Fisher's index", 130, 0.05, {'P': 135.2},
   "Fisher = √(L × P): 130² = 16,900 = 125 × P, so P = 135.2.", hint="Fisher's index is the geometric mean of L and P.")
ch('puc2-statistics-interpolation', 't2', 'Continue the differences',
   'y = 1, 4, 9, 16, ? Choose the next value so the second differences stay constant.',
   [S('yn', 'Next value', 15, 40, 1, 20)], '(yn - 16) - (16 - 9)', 'Last second difference', 2, 0.1, {'yn': 25},
   'First differences 3, 5, 7, 9; second differences are all 2, so the next is 16 + 9 = 25.', hint='Make the difference table.')
ch('puc2-statistics-statistical-inference-testing-of-hypothesis', 't2', 'Just significant',
   'H₀: μ = 50, σ = 10. A sample mean is 52. How large must the sample be for z to reach 1.96?',
   [S('n', 'Sample size', 10, 200, 1, 25)], '(52 - 50)/(10/sqrt(n))', 'z', 1.96, 0.01, {'n': 96},
   'z = (x̄ − μ)/(σ/√n) = 0.2√n = 1.96 gives √n = 9.8, n ≈ 96.', hint='z = (x̄ − μ) / (σ / √n).')
ch('puc2-statistics-population-statistics', 't2', 'Crude death rate 8',
   'A town of 25,000 people. How many deaths in a year give a crude death rate of 8 per thousand?',
   [S('D', 'Deaths', 50, 500, 10, 100)], 'D/25000*1000', 'CDR', 8, 0.05, {'D': 200},
   'CDR = deaths / population × 1000: 200 / 25,000 × 1000 = 8.', unit='per 1000', mode='roll_call')
ch('puc2-statistics-random-variables-and-mathematical-expectation', 't3', 'Expected value 2.1',
   'X takes 1, 2, 3 with probabilities p, 0.3 and 0.7 − p. Choose p so E(X) = 2.1.',
   [S('p', 'p', 0, 0.7, 0.05, 0.1)], '1*p + 2*0.3 + 3*(0.7 - p)', 'E(X)', 2.1, 0.001, {'p': 0.3},
   'E(X) = p + 0.6 + 2.1 − 3p = 2.7 − 2p = 2.1 gives p = 0.3.', hint='E(X) = Σ x P(x); the probabilities add to 1.',
   kind='bar_chart', data={'P(1)': 'p', 'P(2)': 0.3, 'P(3)': '0.7 - p'})


def main():
    touched = set()
    hits = [check(c) for c in CHALLENGES]  # check every challenge before writing any
    for c, hit in zip(CHALLENGES, hits):
        f = PACKS / c['pack'] / 'lessons' / f"{c['topic']}.json"
        raw = f.read_text(encoding='utf-8')
        lesson = json.loads(raw)
        blocks = [b for b in lesson['blocks'] if b.get('id') != BLOCK_ID]
        at = next((i for i, b in enumerate(blocks) if b['type'] == 'class_quiz'), len(blocks))
        blocks.insert(at, c['block'])
        lesson['blocks'] = blocks
        f.write_text(json.dumps(lesson, indent=1, ensure_ascii=False) + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
        touched.add(c['pack'])
        print(f"✓ {c['pack']}/{c['topic']}: {c['block']['goal']} = {hit:.4g} (target {c['block']['target']} ± {c['block']['tolerance']})")
    by = {}
    for c in CHALLENGES:
        k = c['pack'].split('-')[0] + ' ' + c['pack'].split('-')[1]
        by[k] = by.get(k, 0) + 1
    print(f'{len(CHALLENGES)} challenges in {len(touched)} packs:', ', '.join(f'{k} {v}' for k, v in sorted(by.items())))


if __name__ == '__main__':
    main()
