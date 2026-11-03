"""Adds the Science-stream and Commerce subjects to content/syllabus (run once; topics are then
filled by the content packs). Chapter lists follow the rationalised NCERT books (2023-24 onward);
Electronics and Statistics follow the Karnataka Department of PUE syllabus as best recalled and are
flagged for verification in content/REVIEW.md."""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2] / 'content' / 'syllabus'
BOTH, KA, CBSE = ['kar_pu', 'cbse'], ['kar_pu'], ['cbse']
SUBJ = {
  'computer_science': ('Computer Science', 'ಗಣಕ ವಿಜ್ಞಾನ', ['PUC', 'CBSE', 'CUET'], BOTH),
  'electronics': ('Electronics', 'ಎಲೆಕ್ಟ್ರಾನಿಕ್ಸ್', ['PUC'], KA),
  'statistics': ('Statistics', 'ಸಂಖ್ಯಾಶಾಸ್ತ್ರ', ['PUC'], KA),
  'accountancy': ('Accountancy', 'ಲೆಕ್ಕಶಾಸ್ತ್ರ', ['PUC', 'CBSE', 'CUET'], BOTH),
  'business_studies': ('Business Studies', 'ವ್ಯವಹಾರ ಅಧ್ಯಯನ', ['PUC', 'CBSE', 'CUET'], BOTH),
  'economics': ('Economics', 'ಅರ್ಥಶಾಸ್ತ್ರ', ['PUC', 'CBSE', 'CUET'], BOTH),
  'english': ('English', 'ಇಂಗ್ಲಿಷ್', ['CBSE', 'CUET'], CBSE),
}
# (title, book)
CH = {
 ('computer_science','puc1'): [(t,'Computer Science (NCERT)') for t in ["Computer System","Encoding Schemes and Number System","Emerging Trends","Introduction to Problem Solving","Getting Started with Python","Flow of Control","Functions","Strings","Lists","Tuples and Dictionaries","Societal Impact"]],
 ('computer_science','puc2'): [(t,'Computer Science (NCERT)') for t in ["Exception Handling in Python","File Handling in Python","Stack","Queue","Sorting","Searching","Understanding Data","Database Concepts","Structured Query Language (SQL)","Computer Networks","Data Communication","Security Aspects"]],
 ('electronics','puc1'): [(t,'Electronics (Dept. of PUE)') for t in ["Electric Circuit Fundamentals","Passive Components: Resistors, Capacitors and Inductors","AC Fundamentals","Semiconductor Physics","Semiconductor Diodes","Rectifiers and Filters","Bipolar Junction Transistors","Transistor Biasing","Number Systems and Codes","Logic Gates and Boolean Algebra","Electronic Measuring Instruments"]],
 ('electronics','puc2'): [(t,'Electronics (Dept. of PUE)') for t in ["Transistor Amplifiers","Feedback Amplifiers","Oscillators","Operational Amplifiers","Wave Shaping and Multivibrators","Modulation and Demodulation","Radio and Television Communication","Combinational Logic Circuits","Sequential Logic Circuits","Microprocessors and Microcontrollers"]],
 ('statistics','puc1'): [(t,'Statistics (Dept. of PUE)') for t in ["Introduction to Statistics","Collection of Data","Classification and Tabulation","Diagrammatic and Graphical Representation","Measures of Central Tendency","Measures of Dispersion","Moments, Skewness and Kurtosis","Correlation and Regression","Theory of Attributes","Probability"]],
 ('statistics','puc2'): [(t,'Statistics (Dept. of PUE)') for t in ["Population Statistics","Index Numbers","Time Series Analysis","Interpolation","Random Variables and Mathematical Expectation","Theoretical Distributions","Sampling Distributions","Statistical Inference: Testing of Hypothesis","Statistical Quality Control","Operations Research: Linear Programming and Game Theory"]],
 ('accountancy','puc1'): [(t,'Financial Accounting (NCERT)') for t in ["Introduction to Accounting","Theory Base of Accounting","Recording of Transactions I","Recording of Transactions II","Bank Reconciliation Statement","Trial Balance and Rectification of Errors","Depreciation, Provisions and Reserves","Financial Statements I","Financial Statements II"]],
 ('accountancy','puc2'): [(t,b) for t,b in [("Accounting for Partnership: Basic Concepts","Accountancy Part I (NCERT)"),("Reconstitution of a Partnership Firm: Admission of a Partner","Accountancy Part I (NCERT)"),("Reconstitution of a Partnership Firm: Retirement and Death of a Partner","Accountancy Part I (NCERT)"),("Dissolution of a Partnership Firm","Accountancy Part I (NCERT)"),("Accounting for Share Capital","Accountancy Part II (NCERT)"),("Issue and Redemption of Debentures","Accountancy Part II (NCERT)"),("Financial Statements of a Company","Accountancy Part II (NCERT)"),("Analysis of Financial Statements","Accountancy Part II (NCERT)"),("Accounting Ratios","Accountancy Part II (NCERT)"),("Cash Flow Statement","Accountancy Part II (NCERT)")]],
 ('business_studies','puc1'): [(t,'Business Studies (NCERT)') for t in ["Nature and Purpose of Business","Forms of Business Organisation","Public, Private and Global Enterprises","Business Services","Emerging Modes of Business","Social Responsibilities of Business and Business Ethics","Sources of Business Finance","Small Business and Entrepreneurship","Internal Trade","International Business"]],
 ('business_studies','puc2'): [(t,'Business Studies (NCERT)') for t in ["Nature and Significance of Management","Principles of Management","Business Environment","Planning","Organising","Staffing","Directing","Controlling","Financial Management","Financial Markets","Marketing","Consumer Protection"]],
 ('economics','puc1'): [(t,'Statistics for Economics (NCERT)') for t in ["Introduction to Statistics for Economics","Collection of Data","Organisation of Data","Presentation of Data","Measures of Central Tendency","Correlation","Index Numbers"]] + [(t,'Indian Economic Development (NCERT)') for t in ["Indian Economy on the Eve of Independence","Indian Economy 1950–1990","Liberalisation, Privatisation and Globalisation: An Appraisal","Human Capital Formation in India","Rural Development","Employment: Growth, Informalisation and Other Issues","Environment and Sustainable Development","Comparative Development Experiences of India and its Neighbours"]],
 ('economics','puc2'): [(t,'Introductory Microeconomics (NCERT)') for t in ["Introduction to Microeconomics","Theory of Consumer Behaviour","Production and Costs","The Theory of the Firm under Perfect Competition","Market Equilibrium"]] + [(t,'Introductory Macroeconomics (NCERT)') for t in ["Introduction to Macroeconomics","National Income Accounting","Money and Banking","Determination of Income and Employment","Government Budget and the Economy","Open Economy Macroeconomics"]],
 ('english','puc1'): [(t,'Hornbill (NCERT)') for t in ["The Portrait of a Lady","A Photograph (poem)","We're Not Afraid to Die… if We Can All Be Together","Discovering Tut: The Saga Continues","The Voice of the Rain (poem)","Childhood (poem)","The Adventure","Silk Road","Father to Son (poem)"]] + [(t,'Snapshots (NCERT)') for t in ["The Summer of the Beautiful White Horse","The Address","Mother's Day","Birth","The Tale of Melon City"]],
 ('english','puc2'): [(t,'Flamingo (NCERT)') for t in ["The Last Lesson","Lost Spring","Deep Water","The Rattrap","Indigo","Poets and Pancakes","The Interview","Going Places","My Mother at Sixty-six (poem)","Keeping Quiet (poem)","A Thing of Beauty (poem)","A Roadside Stand (poem)","Aunt Jennifer's Tigers (poem)"]] + [(t,'Vistas (NCERT)') for t in ["The Third Level","The Tiger King","Journey to the End of the Earth","The Enemy","On the Face of It","Memories of Childhood"]],
}
def slug(s): return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')

if __name__ == '__main__':
    index = json.loads((ROOT / 'index.json').read_text())
    have = {(s['subject'], s['year']) for s in index['subjects']}
    for (subject, year), chs in CH.items():
        en, kn, exams, boards = SUBJ[subject]
        out = [dict(id=f'{year}-{subject.replace("_","-")}-{i:02d}-{slug(t)}'[:90].rstrip('-'), subject=subject, year=year, number=i, title={'en': t}, topics=[], exams=exams, boards=boards, book=b) for i, (t, b) in enumerate(chs, 1)]
        (ROOT / f'{subject}-{year}.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
        if (subject, year) not in have:
            index['subjects'].append(dict(subject=subject, year=year, title={'en': en, 'kn': kn}, file=f'{subject}-{year}.json', chapters=len(out), boards=boards))
    for s in index['subjects']:
        s.setdefault('boards', BOTH)
    index['board'] = 'Karnataka PU (Dept. of PUE) and CBSE, NCERT rationalised books'
    (ROOT / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    print(sum(len(v) for v in CH.values()), 'new chapters;', len(index['subjects']), 'subject-years')
