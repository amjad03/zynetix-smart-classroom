#!/usr/bin/env python3
"""Converts every lesson in content/packs into the video style of the hand-made sample
(puc1-physics-units-and-measurement t1), deterministically and idempotently.

  python3 tools/voice/stylize.py            # rewrite packs in place
  python3 tools/voice/stylize.py --check    # report what would change, write nothing

Per block (a block that already has `voice` is left alone, so a re-run changes nothing):
  intro       -> step reveal: the hook, then one card per objective ("In this lesson").
  concept     -> step reveal of its points, the block title's key words *accented*.
                 A concept just before a worked example gets a student's question.
  example     -> step reveal: problem, each step, answer.
  pyq         -> the first plain MCQ with an explanation becomes a "pause and solve" block
                 (its explanation split into solution steps); the rest stay a quiz.
  trick       -> rule ("Remember this").
  recap       -> recall: "lhs = ?" questions when every point is "lhs = rhs", else the points
                 revealed one by one; `next` teases the following topic.
  sim / lab / 3D / interactive -> kept; a short generic tryThis where missing.
  Every block gets voice[]: exactly one line per reveal step (mirrors revealSteps() in
  packages/lesson-schema), spoken English from the block's own text (LaTeX and symbols read
  out), and Kannada text from the block's existing Kannada where present.
A pack whose files change gets its patch version bumped (the board installs only newer versions).
Blocks whose text has a literal `*` (code, SQL, spreadsheet formulas) are not accented or revealed:
the board would read `*` as keyword markers.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PACKS = REPO / 'content' / 'packs'
SKIP = {('puc1-physics-units-and-measurement', 't1.json')}

# ------------------------------------------------------------------ spoken text

GREEK = {
    'alpha': 'alpha', 'beta': 'beta', 'gamma': 'gamma', 'delta': 'delta', 'epsilon': 'epsilon', 'varepsilon': 'epsilon',
    'zeta': 'zeta', 'eta': 'eta', 'theta': 'theta', 'vartheta': 'theta', 'iota': 'iota', 'kappa': 'kappa', 'lambda': 'lambda',
    'mu': 'mu', 'nu': 'nu', 'xi': 'xi', 'pi': 'pi', 'rho': 'rho', 'sigma': 'sigma', 'tau': 'tau', 'upsilon': 'upsilon',
    'phi': 'phi', 'varphi': 'phi', 'chi': 'chi', 'psi': 'psi', 'omega': 'omega',
    'Gamma': 'capital gamma', 'Delta': 'delta', 'Theta': 'theta', 'Lambda': 'lambda', 'Pi': 'pi', 'Sigma': 'sigma',
    'Phi': 'phi', 'Psi': 'psi', 'Omega': 'omega',
}
LATEX_WORDS = {
    'times': ' times ', 'cdot': ' times ', 'div': ' divided by ', 'pm': ' plus or minus ', 'mp': ' minus or plus ',
    'approx': ' is approximately ', 'sim': ' is about ', 'neq': ' is not equal to ', 'ne': ' is not equal to ',
    'leq': ' is less than or equal to ', 'le': ' is less than or equal to ', 'geq': ' is greater than or equal to ',
    'ge': ' is greater than or equal to ', 'll': ' is much less than ', 'gg': ' is much greater than ',
    'to': ' to ', 'rightarrow': ' gives ', 'longrightarrow': ' gives ', 'Rightarrow': ' so ', 'implies': ' so ',
    'leftarrow': ' from ', 'leftrightarrow': ' is equivalent to ', 'rightleftharpoons': ' is in equilibrium with ',
    'Leftrightarrow': ' if and only if ', 'propto': ' is proportional to ', 'infty': ' infinity ', 'degree': ' degrees ',
    'sin': ' sine ', 'cos': ' cos ', 'tan': ' tan ', 'cot': ' cot ', 'sec': ' sec ', 'csc': ' cosec ', 'cosec': ' cosec ',
    'log': ' log ', 'ln': ' natural log ', 'exp': ' exponential ', 'lim': ' the limit ', 'int': ' the integral of ',
    'oint': ' the integral of ', 'sum': ' the sum of ', 'prod': ' the product of ', 'partial': ' partial ', 'nabla': ' del ',
    'angle': ' angle ', 'triangle': ' triangle ', 'parallel': ' is parallel to ', 'perp': ' is perpendicular to ',
    'in': ' in ', 'notin': ' not in ', 'subset': ' is a subset of ', 'subseteq': ' is a subset of ', 'cup': ' union ',
    'cap': ' intersection ', 'emptyset': ' the empty set ', 'forall': ' for all ', 'exists': ' there exists ',
    'therefore': ' therefore ', 'because': ' because ', 'circ': ' degrees ', 'prime': ' prime ', 'ldots': ' and so on ',
    'cdots': ' and so on ', 'dots': ' and so on ', 'hbar': ' h bar ', 'ell': ' l ', 'quad': ' ', 'qquad': ' ',
    'neg': ' not ', 'land': ' and ', 'lor': ' or ', 'oplus': ' x o r ', 'equiv': ' is equivalent to ', 'cong': ' is congruent to ',
    'percent': ' percent ', 'deg': ' degrees ',
}
SUP = str.maketrans('⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺ⁿᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣʸᶻ', '0123456789-+nabcdefghijklmoprstuvwxyz')
SUB = str.maketrans('₀₁₂₃₄₅₆₇₈₉₊₋ₐₑₒₓₕₖₗₘₙₚₛₜᵢᵣᵤᵥⱼ', '0123456789+-aeoxhklmnpstiruvj')
UNICODE = [
    ('×', ' times '), ('÷', ' divided by '), ('±', ' plus or minus '), ('≈', ' is approximately '), ('≠', ' is not equal to '),
    ('≤', ' is less than or equal to '), ('≥', ' is greater than or equal to '), ('⇒', ' so '), ('⟹', ' so '), ('⇔', ' if and only if '),
    ('→', ' gives '), ('⟶', ' gives '), ('←', ' from '), ('⇌', ' is in equilibrium with '), ('∝', ' is proportional to '),
    ('∞', ' infinity '), ('√', ' the square root of '), ('∑', ' the sum of '), ('∫', ' the integral of '), ('∆', ' delta '),
    ('°C', ' degrees Celsius'), ('°F', ' degrees Fahrenheit'), ('°', ' degrees'), ('Ω', ' ohms'), ('Δ', 'delta '),
    ('π', ' pi '), ('ρ', ' rho '), ('θ', ' theta '), ('λ', ' lambda '), ('μ', ' micro '), ('α', ' alpha '), ('β', 'beta'),
    ('γ', ' gamma '), ('ω', ' omega '), ('σ', ' sigma '), ('φ', ' phi '), ('ε', ' epsilon '), ('η', ' eta '), ('τ', ' tau '), ('ν', 'nu'),
    ('·', ' '), ('…', '...'), ('−', '-'), ('–', '-'), ('—', ', '), ('“', '"'), ('”', '"'), ('‘', "'"), ('’', "'"),
    ('∠', ' angle '), ('∥', ' is parallel to '), ('⊥', ' is perpendicular to '), ('∴', ' therefore '), ('∵', ' because '),
    ('∈', ' in '), ('∪', ' union '), ('∩', ' intersection '), ('⊂', ' is a subset of '), ('∅', ' the empty set '),
    ('≡', ' is equivalent to '), ('½', ' one half '), ('¼', ' one quarter'), ('¾', ' three quarters'),
]
UNITS = {
    'kg': ('kilogram', 'kilograms'), 'g': ('gram', 'grams'), 'mg': ('milligram', 'milligrams'), 'km': ('kilometre', 'kilometres'),
    'm': ('metre', 'metres'), 'cm': ('centimetre', 'centimetres'), 'mm': ('millimetre', 'millimetres'), 'nm': ('nanometre', 'nanometres'),
    'micro m': ('micrometre', 'micrometres'), 's': ('second', 'seconds'), 'ms': ('millisecond', 'milliseconds'), 'h': ('hour', 'hours'),
    'hr': ('hour', 'hours'), 'min': ('minute', 'minutes'), 'N': ('newton', 'newtons'), 'kN': ('kilonewton', 'kilonewtons'),
    'J': ('joule', 'joules'), 'kJ': ('kilojoule', 'kilojoules'), 'W': ('watt', 'watts'), 'kW': ('kilowatt', 'kilowatts'),
    'kWh': ('kilowatt hour', 'kilowatt hours'), 'Pa': ('pascal', 'pascals'), 'kPa': ('kilopascal', 'kilopascals'), 'K': ('kelvin', 'kelvin'),
    'mol': ('mole', 'moles'), 'mL': ('millilitre', 'millilitres'), 'ml': ('millilitre', 'millilitres'), 'mA': ('milliampere', 'milliamperes'),
    'V': ('volt', 'volts'), 'kV': ('kilovolt', 'kilovolts'), 'Hz': ('hertz', 'hertz'), 'kHz': ('kilohertz', 'kilohertz'), 'MHz': ('megahertz', 'megahertz'),
    'eV': ('electron volt', 'electron volts'), 'MeV': ('mega electron volt', 'mega electron volts'), 'atm': ('atmosphere', 'atmospheres'),
    'ohms': ('ohm', 'ohms'), 'µF': ('microfarad', 'microfarads'), 'μF': ('microfarad', 'microfarads'), 'pF': ('picofarad', 'picofarads'),
    'nF': ('nanofarad', 'nanofarads'), 'mH': ('millihenry', 'millihenries'), 'µA': ('microampere', 'microamperes'), 'μA': ('microampere', 'microamperes'),
    'µm': ('micrometre', 'micrometres'), 'μm': ('micrometre', 'micrometres'), 'µs': ('microsecond', 'microseconds'), 'μs': ('microsecond', 'microseconds'), 'cal': ('calorie', 'calories'), 'kcal': ('kilocalorie', 'kilocalories'),
}
UNIT_RE = '|'.join(sorted((re.escape(u) for u in UNITS), key=len, reverse=True))
# A unit after a number, with an optional power and an optional "/unit" or " unit⁻¹" part.
NUM_UNIT = re.compile(r'(?<![\w.])(\d+(?:\.\d+)?)\s?(' + UNIT_RE + r')(²|³|\^2|\^3)?(?:/(' + UNIT_RE + r')(²|³|\^2|\^3)?)?(?![\w/]|\.\w)')


UNIT_FRAC = re.compile(r'(?<![\w/])(' + UNIT_RE + r')(²|³|\^2|\^3)?/(' + UNIT_RE + r')(²|³|\^2|\^3)?(?![\w/])')


def _power_word(p):
    return {'2': 'squared', '3': 'cubed'}.get(p, f'to the power {p}')


def _unit(u, pw, plural):
    one, many = UNITS[u]
    w = many if plural else one
    if pw in ('²', '^2'):
        return 'square ' + w
    if pw in ('³', '^3'):
        return 'cubic ' + w
    return w


def _num_unit(m):
    num, u, pw, u2, pw2 = m.groups()
    plural = num not in ('1', '1.0')
    s = f'{num} {_unit(u, pw, plural)}'
    if u2:
        if pw2 and u2 in ('s', 'h', 'min'):
            s += f' per {UNITS[u2][0]} squared'
        else:
            s += f' per {_unit(u2, pw2, False)}'
    return s


def _latex(t):
    """Inline LaTeX to spoken words."""
    t = t.replace('\\%', ' percent ').replace('\\,', ' ').replace('\\;', ' ').replace('\\!', '').replace('\\ ', ' ')
    t = re.sub(r'\\(left|right|big|Big|bigg|Bigg)\b\s*([()\[\]|.]|\\[{}])?', lambda m: ' ' if (m.group(2) or '') in ('', '.') else m.group(2), t)
    t = re.sub(r'\\(?:text|mathrm|mathbf|mathit|operatorname|textbf|textit|mbox|rm|mathsf|boldsymbol)\s*\{([^{}]*)\}', r' \1 ', t)
    for _ in range(6):
        t2 = re.sub(r'\\[dt]?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}', r' (\1) over (\2) ', t)
        t2 = re.sub(r'\\sqrt\s*\[([^\]]*)\]\s*\{([^{}]*)\}', r' the \1th root of (\2) ', t2)
        t2 = re.sub(r'\\sqrt\s*\{([^{}]*)\}', r' the square root of (\1) ', t2)
        t2 = re.sub(r'\\(?:vec|overrightarrow)\s*\{([^{}]*)\}', r' vector \1 ', t2)
        t2 = re.sub(r'\\hat\s*\{([^{}]*)\}', r' \1 hat ', t2)
        t2 = re.sub(r'\\(?:overline|bar)\s*\{([^{}]*)\}', r' \1 bar ', t2)
        t2 = re.sub(r'\\dot\s*\{([^{}]*)\}', r' \1 dot ', t2)
        t2 = re.sub(r'\^\s*\{\s*\\circ\s*\}|\^\s*\\circ', ' degrees ', t2)
        t2 = re.sub(r'(\b10|\))\s*\^\s*\{([^{}]*)\}', lambda m: f'{m.group(1)} to the power {m.group(2)} ', t2)
        t2 = re.sub(r'\^\s*\{([^{}]*)\}', lambda m: ' ' + _power_word(m.group(1).strip()) + ' ', t2)
        t2 = re.sub(r'_\s*\{([^{}]*)\}', r' \1 ', t2)
        if t2 == t:
            break
        t = t2
    t = re.sub(r'(\b10)\s*\^\s*(-?\w)', r'\1 to the power \2', t)
    t = re.sub(r'\^\s*(-?\w)', lambda m: ' ' + _power_word(m.group(1)) + ' ', t)
    t = re.sub(r'_\s*(\w)', r' \1', t)

    def cmd(m):
        w = m.group(1)
        if w in GREEK:
            return ' ' + GREEK[w] + ' '
        return LATEX_WORDS.get(w, ' ' + w + ' ')
    t = re.sub(r'\\([A-Za-z]+)', cmd, t)
    t = t.replace('{', ' ').replace('}', ' ').replace('\\', ' ')
    t = re.sub(r'\s*=\s*', ' equals ', t)
    t = re.sub(r'\s*\+\s*', ' plus ', t)
    t = re.sub(r'(?<=[\w)])\s*-\s*(?=[\w(])', ' minus ', t)
    t = re.sub(r'(^|\s|\()-\s*(?=[\w(])', r'\1minus ', t)
    t = re.sub(r'\s*/\s*', ' over ', t)
    t = re.sub(r'\s*<\s*', ' is less than ', t)
    t = re.sub(r'\s*>\s*', ' is greater than ', t)
    t = t.replace('*', ' times ').replace('&', ' ')
    return t


def spoken(text):
    """Plain spoken text for TTS: no accent marks, LaTeX and symbols read out."""
    if not text:
        return ''
    t = text.replace('**', '')
    # Accent markers are *word*; a lone * in code is "star".
    t = re.sub(r'\*([^*\n$]{1,60})\*', r'\1', t)
    parts = t.split('$')
    if len(parts) % 2 == 1:
        t = ''.join(_latex(p) if i % 2 else p for i, p in enumerate(parts))
    t = t.replace('*', ' star ')
    t = re.sub(r'₹\s?([\d,]+(?:\.\d+)?)', lambda m: m.group(1) + (' rupee' if m.group(1) == '1' else ' rupees'), t)
    t = re.sub(r'\b10([⁻⁺]?[⁰¹²³⁴⁵⁶⁷⁸⁹ⁿᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣʸᶻ]+)', lambda m: '10 to the power ' + m.group(1).translate(SUP), t)
    t = NUM_UNIT.sub(_num_unit, t)
    t = UNIT_FRAC.sub(lambda m: _unit(m.group(1), m.group(2), True) + ' per ' + _unit(m.group(3), m.group(4), False), t)
    t = re.sub(r'_\{([^{}]*)\}', r' \1', t)
    t = re.sub(r'(?<=[A-Za-z])_(\w)', r' \1', t)
    t = re.sub(r'([⁻⁺]?[⁰¹²³⁴⁵⁶⁷⁸⁹ⁿᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣʸᶻ]+)', lambda m: ' ' + _power_word(m.group(1).translate(SUP)), t)
    t = re.sub(r'[₀₁₂₃₄₅₆₇₈₉₊₋ₐₑₒₓₕₖₗₘₙₚₛₜᵢᵣᵤᵥⱼ]+', lambda m: ' ' + m.group(0).translate(SUB), t)
    for a, b in UNICODE:
        t = t.replace(a, b)
    t = re.sub(r'(?<=\d)\s*%', ' percent', t)
    t = re.sub(r'(?<=[\w)])\s+=\s+(?=[\w(-])', ' equals ', t)
    t = re.sub(r'(?<=\d)\s*=\s*(?=\d)', ' equals ', t)
    t = re.sub(r'(?<=\d) - (?=\d)', ' minus ', t)
    t = re.sub(r'(?<=[\w)]) \+ (?=[\w(])', ' plus ', t)
    t = re.sub(r'(power |^|[\s(])-\s?(?=\d)', r'\1minus ', t)
    t = re.sub(r'(?<=\w) / (?=\w)', ' divided by ', t)
    t = re.sub(r'(?<=\d)\s*\^\s*(-?\d+)', lambda m: ' to the power ' + m.group(1), t)
    t = re.sub(r'(?<![\w/])([A-Za-z]{1,2}|\d+(?:\.\d+)?)/(?=[A-Za-z0-9(])', r'\1 over ', t)
    t = re.sub(r'_{2,}', ' blank ', t)
    t = re.sub(r'(?<=\S) < (?=\S)', ' is less than ', t)
    t = re.sub(r'(?<=\S) > (?=\S)', ' is greater than ', t)
    t = t.replace('+', ' plus ')
    t = re.sub(r'(^|\s)-(?=\s*[:,;.]|\s+and\b|\s*$)', r'\1minus', t)
    t = re.sub(r'\s+([,.;:!?])', r'\1', t)
    t = re.sub(r'[:;,]+\s*$', '', t.strip())
    t = re.sub(r'\(\s+', '(', t)
    t = re.sub(r'\s+\)', ')', t)
    t = re.sub(r'\(([\w .]{1,24})\)', lambda m: m.group(1) if re.fullmatch(r'[\w .]+', m.group(1)) and ' over ' not in m.group(0) else m.group(0), t)
    t = re.sub(r'\s{2,}', ' ', t).strip()
    if t and t[-1] not in '.!?':
        t += '.'
    return t


def sentences(text):
    t = re.sub(r'\s+', ' ', text or '').strip()
    if not t:
        return []
    out, buf = [], ''
    # Split after . ! ? । followed by a space and a capital, digit, quote or non-Latin letter; keep $…$ whole.
    for piece in re.split(r'(?<=[.!?।])\s+(?=[A-Z0-9"“(\u0C80-\u0CFF$])', t):
        buf = f'{buf} {piece}'.strip() if buf else piece
        if buf.count('$') % 2 == 0 and not re.search(r'\b(e\.g|i\.e|etc|vs|approx|Fig|No|Eq|viz|Dr|Mr|Mrs|St)\.$', buf):
            out.append(buf)
            buf = ''
    if buf:
        out.append(buf)
    return out


def say(en, kn=None):
    s = {'en': spoken(en)}
    if kn:
        s['kn'] = spoken(kn)
    return {'say': s}


def join_l(*parts):
    return ' '.join(p.strip() for p in parts if p and p.strip())


# ------------------------------------------------------------------ accents

STOP = set('''a an the and or of in on at to for from by with into onto over under is are was were be been being as its it this that
these those their his her our your we you they he she them than then so but not no yes how why what when where which who whom whose
do does did can could will would shall should may might must using use used between among about across per each every all any some
more most less least very also only just one two three four five six seven eight nine ten part parts type types kind kinds rules rule
introduction basic basics simple meaning example examples case cases method methods idea ideas key points summary overview revision
formula formulas law laws properties property chapter topic lesson unit units'''.split())


def _strip_math(t):
    return re.sub(r'\$[^$]*\$', lambda m: '\0' * len(m.group(0)), t)


def key_phrases(title):
    words = re.findall(r"[A-Za-z][A-Za-z'-]*", title or '')
    out = []
    for n in (3, 2, 1):
        for i in range(len(words) - n + 1):
            g = words[i:i + n]
            if g[0].lower() in STOP or g[-1].lower() in STOP:
                continue
            if n == 1 and len(g[0]) < 5:
                continue
            p = ' '.join(g)
            if p not in out:
                out.append(p)
    return out


def accent(text, phrases):
    """Wraps the first title phrase found in `text` (outside $…$) in *…*; at most one per text."""
    if not text or '*' in text:
        return text
    masked = _strip_math(text)
    for p in phrases:
        m = re.search(r'(?<![\w*])(' + re.escape(p) + r')(?:s|es)?(?![\w*])', masked, re.I)
        if m:
            a, b = m.span(0)
            return text[:a] + '*' + text[a:b] + '*' + text[b:]
    return text


def has_star(*texts):
    return any(t and '*' in t for t in texts)


# ------------------------------------------------------------------ templates (no facts, only framing)

NEXT_LABEL = lambda k: {'en': f'Next · Topic {k}', 'kn': f'ಮುಂದೆ · ವಿಷಯ {k}'}
IN_LESSON = {'en': 'In this lesson', 'kn': 'ಈ ಪಾಠದಲ್ಲಿ'}
ASK_EXAMPLE = [
    ('aarav', {'en': 'Can we try one *example* on this?', 'kn': 'ಇದರ ಮೇಲೆ ಒಂದು *ಉದಾಹರಣೆ* ಮಾಡೋಣವೇ?'}),
    ('diya', {'en': 'How do we use this in a *problem*?', 'kn': 'ಇದನ್ನು ಒಂದು *ಸಮಸ್ಯೆಯಲ್ಲಿ* ಹೇಗೆ ಬಳಸುವುದು?'}),
]
TRY_IT = [
    ('diya', {'en': 'Let me try it *myself* first!', 'kn': 'ನಾನೇ ಮೊದಲು *ಪ್ರಯತ್ನಿಸುತ್ತೇನೆ*!'}),
    ('aarav', {'en': 'I want to see what *changes*.', 'kn': 'ಏನು *ಬದಲಾಗುತ್ತದೆ* ಎಂದು ನೋಡಬೇಕು.'}),
]
TRY_LAB = [
    {'en': 'Read the aim, then change one setting at a time.', 'kn': 'ಉದ್ದೇಶವನ್ನು ಓದಿ, ನಂತರ ಒಮ್ಮೆಗೆ ಒಂದೇ ಸೆಟ್ಟಿಂಗ್ ಬದಲಿಸಿ.'},
    {'en': 'Note each reading before you change the next setting.', 'kn': 'ಮುಂದಿನ ಸೆಟ್ಟಿಂಗ್ ಬದಲಿಸುವ ಮೊದಲು ಪ್ರತಿ ಓದನ್ನೂ ಬರೆದುಕೊಳ್ಳಿ.'},
]
TRY_3D = [
    {'en': 'Drag to turn the model and look at it from every side.', 'kn': 'ಮಾದರಿಯನ್ನು ಎಳೆದು ತಿರುಗಿಸಿ, ಎಲ್ಲ ಕಡೆಯಿಂದ ನೋಡಿ.'},
    {'en': 'Zoom in on the part the caption names.', 'kn': 'ಶೀರ್ಷಿಕೆಯಲ್ಲಿ ಹೇಳಿದ ಭಾಗವನ್ನು ಜೂಮ್ ಮಾಡಿ ನೋಡಿ.'},
]
TRY_PLAY = [{'en': 'Change one control at a time and watch what happens.', 'kn': 'ಒಮ್ಮೆಗೆ ಒಂದೇ ನಿಯಂತ್ರಣ ಬದಲಿಸಿ, ಏನಾಗುತ್ತದೆ ನೋಡಿ.'}]
SOLVE_NARRATION = {'en': 'Pause and solve this exam pattern question.', 'kn': 'ನಿಲ್ಲಿಸಿ, ಈ ಪರೀಕ್ಷಾ ಮಾದರಿಯ ಪ್ರಶ್ನೆಯನ್ನು ಬಿಡಿಸಿ.'}
ANSWER_IS = ('So the answer is', 'ಆದ್ದರಿಂದ ಉತ್ತರ:')


def en(x):
    return (x or {}).get('en', '')


def kn(x):
    return (x or {}).get('kn')


def narr(b):
    return b.get('narration') or {}


# ------------------------------------------------------------------ per block

def steps_of(b, qmap):
    """Mirror of revealSteps() in packages/lesson-schema."""
    t = b['type']
    if t == 'class_quiz' and b.get('style') == 'pause':
        return 2 * len(b['questionIds'])
    if t == 'pyq' and b.get('style') == 'solve':
        q = qmap.get(b['questionIds'][0])
        return 1 + (len(q['solution']) if q and q.get('solution') else 1)
    if not b.get('reveal'):
        return 1
    n = {'intro': lambda: len(b.get('cards') or []),
         'concept': lambda: (1 if b.get('hero') else 0) + len(b.get('cards') or []) + len(b.get('points') or []),
         'example': lambda: len(b['steps']) + 2,
         'recap': lambda: len(b['points']) + (1 if b.get('next') else 0)}.get(t, lambda: 1)()
    return max(1, n)


def one_line(b):
    """The whole block in one line: its narration, else its main text."""
    n = narr(b)
    if en(n):
        return say(en(n), kn(n))
    for k in ('caption', 'aim', 'prompt', 'body', 'hook', 'heading', 'title'):
        if isinstance(b.get(k), dict) and en(b[k]):
            return say(join_l(en(b.get('title')) if k not in ('title', 'heading') else '', en(b[k])), kn(b[k]))
    return say('Let us look at this together.', 'ಇದನ್ನು ಒಟ್ಟಿಗೆ ನೋಡೋಣ.')


def contains(hay, needle):
    norm = lambda s: re.sub(r'[\W_]+', ' ', s or '').lower().strip()
    return bool(needle) and norm(needle) in norm(hay)


def style_intro(b, ctx):
    phrases = key_phrases(ctx['title'])
    if not has_star(en(b['hook'])):
        b['hook'] = {**b['hook'], 'en': accent(en(b['hook']), phrases)}
    objs = (b.get('objectives') or [])[:8]
    if objs and 'cards' not in b:
        b['cardsTitle'] = dict(IN_LESSON)
        b['cards'] = [{'title': dict(o), 'icon': 'check'} for o in objs]
    b['reveal'] = True
    cards = b.get('cards') or []
    lead_en = en(narr(b)) or en(b['hook'])
    lead_kn = kn(narr(b)) or kn(b['hook'])
    if not cards:
        return [say(lead_en, lead_kn)]
    lines = []
    for i, c in enumerate(cards):
        t = c['title']
        if i == 0:
            lines.append(say(join_l(lead_en, 'In this lesson:', en(t)), join_l(lead_kn, IN_LESSON['kn'] + ':', kn(t)) if lead_kn and kn(t) else None))
        else:
            lines.append(say(en(t), kn(t)))
    return lines


def style_concept(b, ctx, nxt):
    pts = b.get('points') or []
    texts = [en(b['body'])] + [en(p) for p in pts] + [kn(b['body'])] + [kn(p) for p in pts]
    plain = has_star(*texts) or b.get('cards') or b.get('hero')
    if not plain:
        phrases = key_phrases(en(b.get('title'))) + key_phrases(ctx['title'])
        b['body'] = {**b['body'], 'en': accent(en(b['body']), phrases)}
        b['points'] = [{**p, 'en': accent(en(p), phrases)} for p in pts]
        b['reveal'] = True
        pts = b['points']
        if nxt is not None and nxt.get('type') == 'example' and 'speaker' not in b:
            who, line = ASK_EXAMPLE[ctx['ask'] % 2]
            ctx['ask'] += 1
            b['speaker'] = {'who': who, 'say': dict(line)}
    if not b.get('reveal'):
        return [one_line(b)]
    n = steps_of(b, {})
    lead_en = en(narr(b)) or join_l(en(b.get('title')), en(b['body']))
    lead_kn = kn(narr(b)) or kn(b['body'])
    if b.get('cards') or b.get('hero') or not pts:
        rest = [say(en(p), kn(p)) for p in pts]
        return ([say(lead_en, lead_kn)] + rest)[:n] + [say('Let us continue.')] * max(0, n - 1 - len(rest))
    lines = []
    for i, p in enumerate(pts):
        if i == 0:
            first_en = lead_en if contains(lead_en, en(p)) else join_l(lead_en, en(p))
            first_kn = (lead_kn if contains(lead_kn, kn(p)) else join_l(lead_kn, kn(p))) if lead_kn and kn(p) else lead_kn
            lines.append(say(first_en, first_kn))
        else:
            lines.append(say(en(p), kn(p)))
    return lines


def style_example(b, ctx):
    if has_star(en(b['problem']), en(b['answer']), *[en(s) for s in b['steps']]):
        return [one_line(b)]
    b['reveal'] = True
    n = narr(b)
    lead_en = en(n) if contains(en(n), en(b['problem'])) else join_l(en(n), en(b['problem']))
    lead_kn = (kn(n) if contains(kn(n), kn(b['problem'])) else join_l(kn(n), kn(b['problem']))) if kn(n) or kn(b['problem']) else None
    lines = [say(lead_en, lead_kn)]
    lines += [say(en(s), kn(s)) for s in b['steps']]
    a_en, a_kn = en(b['answer']), kn(b['answer'])
    lines.append(say(f'{ANSWER_IS[0]} {a_en}', f'{ANSWER_IS[1]} {a_kn}' if a_kn else None))
    return lines


def solution_steps(q):
    """The question's own explanation split into at most 8 short steps, one sentence each."""
    se = sentences(en(q.get('explanation')))
    if not se:
        return None
    if len(se) > 8:
        se = se[:7] + [' '.join(se[7:])]
    sk = sentences(kn(q.get('explanation'))) if kn(q.get('explanation')) else []
    if len(sk) > 8:
        sk = sk[:7] + [' '.join(sk[7:])]
    return [{'en': e, **({'kn': sk[i]} if len(sk) == len(se) else {})} for i, e in enumerate(se)]


def solve_lines(b, q):
    n = narr(b)
    lines = [say(join_l(en(n), en(q['stem'])), join_l(kn(n), kn(q['stem'])) if kn(n) and kn(q['stem']) else None)]
    steps = q.get('solution') or ([q['explanation']] if q.get('explanation') else [])
    lines += [say(en(s), kn(s)) for s in steps] or [say('Check your answer.', 'ನಿಮ್ಮ ಉತ್ತರ ಪರಿಶೀಲಿಸಿ.')]
    return lines


def solvable(q):
    return (q is not None and q.get('format', 'mcq') == 'mcq' and len(q.get('options') or []) == 4
            and en(q.get('explanation')) and not has_star(en(q['stem']), *[en(o) for o in q['options']]))


def style_pyq(b, ctx, out_blocks, ids):
    """Returns the blocks that replace `b` (a solve block first, when one of its questions fits)."""
    qmap = ctx['qmap']
    pick = next((qid for qid in b['questionIds'] if solvable(qmap.get(qid))), None)
    if pick is None:
        b['voice'] = [one_line(b) if en(narr(b)) else say('Now try these exam pattern questions.', 'ಈಗ ಈ ಪರೀಕ್ಷಾ ಮಾದರಿಯ ಪ್ರಶ್ನೆಗಳನ್ನು ಪ್ರಯತ್ನಿಸಿ.')]
        return [b]
    q = qmap[pick]
    if not q.get('solution'):
        sol = solution_steps(q)
        if sol:
            q['solution'] = sol
            ctx['qchanged'] = True
    rest = [x for x in b['questionIds'] if x != pick]
    if not rest:
        b['style'] = 'solve'
        b['questionIds'] = [pick]
        b['voice'] = solve_lines(b, q)
        return [b]
    sid = f"{b['id']}-solve"
    k = 2
    while sid in ids:
        sid = f"{b['id']}-solve{k}"
        k += 1
    ids.add(sid)
    s = {'id': sid, 'type': 'pyq'}
    if b.get('boards'):
        s['boards'] = list(b['boards'])
    if b.get('title'):
        s['title'] = dict(b['title'])
    s.update({'questionIds': [pick], 'exams': list(b.get('exams') or []), 'style': 'solve', 'narration': dict(SOLVE_NARRATION)})
    s['voice'] = solve_lines(s, q)
    b['questionIds'] = rest
    b['voice'] = [one_line(b) if en(narr(b)) else say('Now try these exam pattern questions.', 'ಈಗ ಈ ಪರೀಕ್ಷಾ ಮಾದರಿಯ ಪ್ರಶ್ನೆಗಳನ್ನು ಪ್ರಯತ್ನಿಸಿ.')]
    return [s, b]


def style_trick(b, ctx):
    if not b.get('style') and not has_star(en(b['heading']), en(b['body']), kn(b.get('heading')), kn(b.get('body'))):
        b['style'] = 'rule'
    return [one_line(b)]


SPLIT = re.compile(r'^(.{2,60}?)\s*(=|:|→)\s+(.+)$')


def recall_qa(points):
    """'lhs = rhs' points as ('lhs = ?', 'rhs') pairs, when every point (and its Kannada) splits."""
    qs, ans = [], []
    for p in points:
        m = SPLIT.match(en(p))
        if not m or '$' in m.group(1) or m.group(1).count('(') != m.group(1).count(')'):
            return None
        qk = ak = None
        if kn(p):
            mk = SPLIT.match(kn(p))
            if not mk or mk.group(2) != m.group(2):
                return None
            qk, ak = f'{mk.group(1)} {mk.group(2)} ?', mk.group(3)
        q = {'en': f'{m.group(1)} {m.group(2)} ?'}
        a = {'en': m.group(3)}
        if qk:
            q['kn'], a['kn'] = qk, ak
        qs.append(q)
        ans.append(a)
    return qs, ans


def style_recap(b, ctx):
    texts = [en(p) for p in b['points']] + [kn(p) for p in b['points']]
    if has_star(*texts) or len(b['points']) > 8:
        return [one_line(b)]
    qa = recall_qa(b['points']) if not b.get('answers') else None
    if qa:
        b['points'], b['answers'] = qa
    b['style'] = 'recall'
    b['reveal'] = True
    if ctx['next'] and 'next' not in b:
        b['next'] = ctx['next']
    lines = []
    pts, ans = b['points'], b.get('answers') or []
    for i, p in enumerate(pts):
        e = en(p) if not ans else join_l(en(p).replace(' ?', '?').replace('= ?', 'is what?'), en(ans[i]))
        k_ = kn(p) if not ans else (join_l(kn(p).replace(' ?', '?'), kn(ans[i])) if kn(p) and kn(ans[i]) else None)
        if i == 0:
            e = join_l('Can you recall these?' if ans else 'Let us recall the key ideas.', e)
            k_ = join_l('ಇವುಗಳನ್ನು ನೆನಪಿಸಿಕೊಳ್ಳಬಲ್ಲಿರಾ?' if ans else 'ಮುಖ್ಯ ಅಂಶಗಳನ್ನು ನೆನಪಿಸಿಕೊಳ್ಳೋಣ.', k_) if k_ else None
        lines.append(say(e, k_))
    if b.get('next'):
        nt = b['next']['title']
        lines.append(say(f"Next: {en(nt)}", f"ಮುಂದೆ: {kn(nt)}" if kn(nt) else None))
    return lines


def style_play(b, ctx):
    t = b['type']
    if not b.get('tryThis'):
        b['tryThis'] = [dict(x) for x in {'virtual_lab': TRY_LAB, '3d_model': TRY_3D}.get(t, TRY_PLAY)]
    if t in ('virtual_lab', '3d_model', 'simulation') and 'speaker' not in b:
        who, line = TRY_IT[ctx['try'] % 2]
        ctx['try'] += 1
        b['speaker'] = {'who': who, 'say': dict(line)}
    return [one_line(b)]


def fix_line(line):
    """Voice text never carries accent stars; Kannada falls back to nothing (English plays)."""
    s = line['say']
    if not s.get('en'):
        s['en'] = 'Let us continue.'
    if 'kn' in s and not s['kn']:
        del s['kn']
    return line


def stylize_lesson(lesson, ctx):
    blocks = lesson['blocks']
    ids = {b['id'] for b in blocks}
    out = []
    for i, b in enumerate(blocks):
        if 'voice' in b:
            out.append(b)
            continue
        nxt = blocks[i + 1] if i + 1 < len(blocks) else None
        t = b['type']
        if t == 'pyq':
            for x in style_pyq(b, ctx, out, ids):
                x['voice'] = [fix_line(v) for v in x['voice']]
                out.append(x)
            continue
        if t == 'intro':
            lines = style_intro(b, ctx)
        elif t == 'concept':
            lines = style_concept(b, ctx, nxt)
        elif t == 'example':
            lines = style_example(b, ctx)
        elif t == 'trick':
            lines = style_trick(b, ctx)
        elif t == 'recap':
            lines = style_recap(b, ctx)
        elif t in ('simulation', 'virtual_lab', '3d_model', 'interactive'):
            lines = style_play(b, ctx)
        else:
            lines = [one_line(b)]
        need = steps_of(b, ctx['qmap'])
        if len(lines) != need:
            raise SystemExit(f"{lesson['id']}/{b['id']}: {len(lines)} voice lines for {need} steps")
        b['voice'] = [fix_line(v) for v in lines]
        out.append(b)
    lesson['blocks'] = out
    for b in out:
        if len(b['voice']) != steps_of(b, ctx['qmap']):
            raise SystemExit(f"{lesson['id']}/{b['id']}: voice count mismatch")


# ------------------------------------------------------------------ files

def load(p):
    s = p.read_text(encoding='utf-8')
    return json.loads(s), s.endswith('\n')


def dump(obj, nl):
    return json.dumps(obj, indent=1, ensure_ascii=False) + ('\n' if nl else '')


def bump(v):
    a, b, c = (int(x) for x in v.split('.'))
    return f'{a}.{b}.{c + 1}'


def lesson_no(p):
    m = re.match(r't(\d+)\.json$', p.name)
    return int(m.group(1)) if m else 10 ** 6


def main():
    check = '--check' in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith('--')]
    changed_packs = blocks_done = lessons_done = 0
    for pack in sorted(PACKS.iterdir()):
        if not pack.is_dir() or (only and not any(pack.name.startswith(o) for o in only)):
            continue
        qpath = pack / 'questions.json'
        questions, qnl = load(qpath)
        qbefore = dump(questions, qnl)
        qmap = {q['id']: q for q in questions}
        files = sorted((pack / 'lessons').glob('*.json'), key=lesson_no)
        lessons = [(f, *load(f)) for f in files]
        writes = {}
        for i, (f, lesson, nl) in enumerate(lessons):
            if (pack.name, f.name) in SKIP:
                continue
            before = dump(lesson, nl)
            nxt = None
            if i + 1 < len(lessons):
                nl_ = lessons[i + 1][1]
                nxt = {'label': NEXT_LABEL(i + 2), 'title': dict(nl_['title'])}
            ctx = {'title': en(lesson['title']), 'qmap': qmap, 'next': nxt, 'ask': lesson_no(f) % 2, 'try': lesson_no(f) % 2, 'qchanged': False}
            pending = sum(1 for b in lesson['blocks'] if 'voice' not in b)
            stylize_lesson(lesson, ctx)
            after = dump(lesson, nl)
            if after != before:
                writes[f] = after
                lessons_done += 1
                blocks_done += pending
        qafter = dump(questions, qnl)
        if qafter != qbefore:
            writes[qpath] = qafter
        if writes:
            changed_packs += 1
            pj = pack / 'pack.json'
            meta, pnl = load(pj)
            meta['version'] = bump(meta['version'])
            writes[pj] = dump(meta, pnl)
            if not check:
                for p, s in writes.items():
                    p.write_text(s, encoding='utf-8')
    print(f"{'would change' if check else 'changed'}: {changed_packs} packs, {lessons_done} lessons, {blocks_done} blocks")


if __name__ == '__main__':
    main()
