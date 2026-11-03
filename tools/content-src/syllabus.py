"""Writes content/syllabus/*.json: the NCERT (rationalised, 2023-24 onward) chapter lists that
Karnataka PU follows. Topics are filled for the seeded chapters only; the CMS adds the rest.
Kannada titles are given for subjects and seeded chapters; others are added after native review."""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2] / 'content' / 'syllabus'
EXAMS = {
    'physics': ['PUC', 'KCET', 'COMEDK', 'NEET', 'JEE'],
    'chemistry': ['PUC', 'KCET', 'COMEDK', 'NEET', 'JEE'],
    'maths': ['PUC', 'KCET', 'COMEDK', 'JEE'],
    'biology': ['PUC', 'KCET', 'NEET'],
}
CH = {
 ('physics','puc1'): ["Units and Measurement","Motion in a Straight Line","Motion in a Plane","Laws of Motion","Work, Energy and Power","System of Particles and Rotational Motion","Gravitation","Mechanical Properties of Solids","Mechanical Properties of Fluids","Thermal Properties of Matter","Thermodynamics","Kinetic Theory","Oscillations","Waves"],
 ('physics','puc2'): ["Electric Charges and Fields","Electrostatic Potential and Capacitance","Current Electricity","Moving Charges and Magnetism","Magnetism and Matter","Electromagnetic Induction","Alternating Current","Electromagnetic Waves","Ray Optics and Optical Instruments","Wave Optics","Dual Nature of Radiation and Matter","Atoms","Nuclei","Semiconductor Electronics: Materials, Devices and Simple Circuits"],
 ('chemistry','puc1'): ["Some Basic Concepts of Chemistry","Structure of Atom","Classification of Elements and Periodicity in Properties","Chemical Bonding and Molecular Structure","Thermodynamics","Equilibrium","Redox Reactions","Organic Chemistry: Some Basic Principles and Techniques","Hydrocarbons"],
 ('chemistry','puc2'): ["Solutions","Electrochemistry","Chemical Kinetics","The d- and f-Block Elements","Coordination Compounds","Haloalkanes and Haloarenes","Alcohols, Phenols and Ethers","Aldehydes, Ketones and Carboxylic Acids","Amines","Biomolecules"],
 ('maths','puc1'): ["Sets","Relations and Functions","Trigonometric Functions","Complex Numbers and Quadratic Equations","Linear Inequalities","Permutations and Combinations","Binomial Theorem","Sequences and Series","Straight Lines","Conic Sections","Introduction to Three Dimensional Geometry","Limits and Derivatives","Statistics","Probability"],
 ('maths','puc2'): ["Relations and Functions","Inverse Trigonometric Functions","Matrices","Determinants","Continuity and Differentiability","Application of Derivatives","Integrals","Application of Integrals","Differential Equations","Vector Algebra","Three Dimensional Geometry","Linear Programming","Probability"],
 ('biology','puc1'): ["The Living World","Biological Classification","Plant Kingdom","Animal Kingdom","Morphology of Flowering Plants","Anatomy of Flowering Plants","Structural Organisation in Animals","Cell: The Unit of Life","Biomolecules","Cell Cycle and Cell Division","Photosynthesis in Higher Plants","Respiration in Plants","Plant Growth and Development","Breathing and Exchange of Gases","Body Fluids and Circulation","Excretory Products and their Elimination","Locomotion and Movement","Neural Control and Coordination","Chemical Coordination and Integration"],
 ('biology','puc2'): ["Sexual Reproduction in Flowering Plants","Human Reproduction","Reproductive Health","Principles of Inheritance and Variation","Molecular Basis of Inheritance","Evolution","Human Health and Disease","Microbes in Human Welfare","Biotechnology: Principles and Processes","Biotechnology and its Applications","Organisms and Populations","Ecosystem","Biodiversity and Conservation"],
}
KN = {
 ('physics','puc1',2): 'ಸರಳ ರೇಖೆಯಲ್ಲಿ ಚಲನೆ',
 ('chemistry','puc2',1): 'ದ್ರಾವಣಗಳು',
}
TOPICS = {
 ('physics','puc1',2): [
   ('t1', 'Position, displacement and average velocity', 'ಸ್ಥಾನ, ಸ್ಥಾನಪಲ್ಲಟ ಮತ್ತು ಸರಾಸರಿ ವೇಗ', '2.1'),
   ('t2', 'Instantaneous velocity and speed', 'ತಾತ್ಕ್ಷಣಿಕ ವೇಗ ಮತ್ತು ಜವ', '2.2'),
   ('t3', 'Acceleration', 'ವೇಗೋತ್ಕರ್ಷ', '2.3'),
   ('t4', 'Kinematic equations for uniformly accelerated motion', 'ಏಕರೂಪ ವೇಗೋತ್ಕರ್ಷದ ಚಲನೆಯ ಸಮೀಕರಣಗಳು', '2.4'),
   ('t5', 'Free fall and motion graphs', 'ಮುಕ್ತ ಪತನ ಮತ್ತು ಚಲನೆಯ ನಕ್ಷೆಗಳು', '2.4'),
 ],
 ('chemistry','puc2',1): [
   ('t1', 'Types of solutions and expressing concentration', 'ದ್ರಾವಣಗಳ ವಿಧಗಳು ಮತ್ತು ಸಾರತೆಯ ಅಭಿವ್ಯಕ್ತಿ', '1.1–1.2'),
   ('t2', "Solubility and Henry's law", 'ವಿಲೇಯತೆ ಮತ್ತು ಹೆನ್ರಿಯ ನಿಯಮ', '1.3'),
   ('t3', "Vapour pressure, Raoult's law and ideal solutions", 'ಬಾಷ್ಪ ಒತ್ತಡ, ರೌಲ್ಟ್‌ನ ನಿಯಮ ಮತ್ತು ಆದರ್ಶ ದ್ರಾವಣಗಳು', '1.4–1.5'),
   ('t4', 'Colligative properties', 'ಸಂಖ್ಯಾಧಾರಿತ ಗುಣಗಳು', '1.6'),
   ('t5', "Abnormal molar masses and the van't Hoff factor", "ಅಸಹಜ ಮೋಲಾರ್ ರಾಶಿ ಮತ್ತು ವ್ಯಾಂಟ್ ಹಾಫ್ ಅಂಶ", '1.7'),
 ],
}
SUBJECT_KN = {'physics': 'ಭೌತಶಾಸ್ತ್ರ', 'chemistry': 'ರಸಾಯನಶಾಸ್ತ್ರ', 'maths': 'ಗಣಿತ', 'biology': 'ಜೀವಶಾಸ್ತ್ರ'}

def slug(s): return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')

def chapter_id(subject, year, n, title): return f'{year}-{subject}-{n:02d}-{slug(title)}'[:80].rstrip('-')

if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    index = {'board': 'Karnataka PU (NCERT, rationalised)', 'subjects': []}
    for (subject, year), titles in CH.items():
        chapters = []
        for i, t in enumerate(titles, 1):
            cid = chapter_id(subject, year, i, t)
            title = {'en': t}
            if (subject, year, i) in KN: title['kn'] = KN[(subject, year, i)]
            topics = [dict(id=f'{cid}.{tid}', title={'en': en, 'kn': kn}, ncert=sec) for tid, en, kn, sec in TOPICS.get((subject, year, i), [])]
            chapters.append(dict(id=cid, subject=subject, year=year, number=i, title=title, topics=topics, exams=EXAMS[subject]))
        (ROOT / f'{subject}-{year}.json').write_text(json.dumps(chapters, ensure_ascii=False, indent=2) + '\n')
        index['subjects'].append(dict(subject=subject, year=year, title={'en': subject.capitalize(), 'kn': SUBJECT_KN[subject]}, file=f'{subject}-{year}.json', chapters=len(chapters)))
    (ROOT / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    print(sum(len(v) for v in CH.values()), 'chapters')
