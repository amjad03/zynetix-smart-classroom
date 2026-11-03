import '../engine/model.dart';

/// Board UI text in English and Kannada (Kannada to be checked by a native speaker,
/// like the content: see content/README.md).
const _s = <String, (String, String)>{
  'teacherMode': ('Teacher Mode', 'ಶಿಕ್ಷಕರ ಮೋಡ್'),
  'teacherModeSub': ('Teach a topic with the board', 'ಬೋರ್ಡ್‌ನೊಂದಿಗೆ ಪಾಠ ಮಾಡಿ'),
  'selfLearning': ('Self-Learning Mode', 'ಸ್ವಯಂ ಕಲಿಕೆ ಮೋಡ್'),
  'selfLearningSub': ('A full period, no teacher needed', 'ಶಿಕ್ಷಕರಿಲ್ಲದೆ ಪೂರ್ಣ ಅವಧಿ'),
  'continue': ('Continue', 'ಮುಂದುವರಿಸಿ'),
  'start': ('Start', 'ಪ್ರಾರಂಭಿಸಿ'),
  'back': ('Back', 'ಹಿಂದೆ'),
  'next': ('Next', 'ಮುಂದೆ'),
  'pause': ('Pause', 'ತಡೆ'),
  'resume': ('Resume', 'ಮುಂದುವರಿಸಿ'),
  'pen': ('Pen', 'ಪೆನ್'),
  'quiz': ('Quiz', 'ರಸಪ್ರಶ್ನೆ'),
  'readAloud': ('Read aloud', 'ಓದಿ ಹೇಳು'),
  'finish': ('Finish', 'ಮುಗಿಸಿ'),
  'home': ('Home', 'ಮುಖಪುಟ'),
  'taught': ('Taught', 'ಕಲಿಸಲಾಗಿದೆ'),
  'comingSoon': ('Coming in a content update', 'ಮುಂದಿನ ಅಪ್‌ಡೇಟ್‌ನಲ್ಲಿ'),
  'example': ('Example', 'ಉದಾಹರಣೆ'),
  'showStep': ('Show next step', 'ಮುಂದಿನ ಹಂತ'),
  'answer': ('Answer', 'ಉತ್ತರ'),
  'trick': ('Trick', 'ತಂತ್ರ'),
  'recap': ('Recap', 'ಪುನರಾವರ್ತನೆ'),
  'homework': ('Homework', 'ಮನೆಗೆಲಸ'),
  'pyq': ('Exam questions', 'ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'),
  'pyqPattern': ('Exam pattern', 'ಪರೀಕ್ಷಾ ಮಾದರಿ'),
  'classQuiz': ('Class quiz', 'ತರಗತಿ ರಸಪ್ರಶ್ನೆ'),
  'monitorTaps': ('Discuss, raise hands. Monitor: tap the class answer', 'ಚರ್ಚಿಸಿ, ಕೈ ಎತ್ತಿ. ಮಾನಿಟರ್: ತರಗತಿಯ ಉತ್ತರ ಒತ್ತಿ'),
  'pickRoll': ('Pick a roll number', 'ರೋಲ್ ಸಂಖ್ಯೆ ಆರಿಸಿ'),
  'rollNo': ('Roll No.', 'ರೋಲ್ ಸಂ.'),
  'correct': ('Correct', 'ಸರಿ'),
  'wrong': ('Wrong', 'ತಪ್ಪು'),
  'skip': ('Skip', 'ಬಿಡಿ'),
  'absent': ('Absent', 'ಗೈರು'),
  'team': ('Team', 'ತಂಡ'),
  'teamTurn': ('Team turn', 'ತಂಡದ ಸರದಿ'),
  'score': ('Score', 'ಅಂಕ'),
  'reveal': ('Reveal answer', 'ಉತ್ತರ ತೋರಿಸಿ'),
  'nextQuestion': ('Next question', 'ಮುಂದಿನ ಪ್ರಶ್ನೆ'),
  'done': ('Done', 'ಮುಗಿಯಿತು'),
  'enterPin': ('Teacher PIN', 'ಶಿಕ್ಷಕರ ಪಿನ್'),
  'wrongPin': ('Wrong PIN', 'ತಪ್ಪು ಪಿನ್'),
  'exit': ('Exit', 'ನಿರ್ಗಮಿಸಿ'),
  'cancel': ('Cancel', 'ರದ್ದು'),
  'nowPlaying': ('Now', 'ಈಗ'),
  'periodEnds': ('Period ends in', 'ಅವಧಿ ಮುಗಿಯಲು'),
  'tryThis': ('Try this', 'ಇದನ್ನು ಪ್ರಯತ್ನಿಸಿ'),
  'aim': ('Aim', 'ಉದ್ದೇಶ'),
  'whatYouLearn': ('In this lesson', 'ಈ ಪಾಠದಲ್ಲಿ'),
  'chooseTopic': ('Choose a topic', 'ವಿಷಯ ಆರಿಸಿ'),
  'nextTopic': ('Next topic for this class', 'ಈ ತರಗತಿಗೆ ಮುಂದಿನ ವಿಷಯ'),
  'scheduled': ('Scheduled by the college', 'ಕಾಲೇಜು ನಿಗದಿಪಡಿಸಿದೆ'),
  'periodOver': ('Period over. Well done, class!', 'ಅವಧಿ ಮುಗಿಯಿತು. ಚೆನ್ನಾಗಿದೆ!'),
  'offlineOk': ('Works offline', 'ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಕೆಲಸ ಮಾಡುತ್ತದೆ'),
  'readCase': ('Read the case', 'ಪ್ರಕರಣವನ್ನು ಓದಿ'),
  'cbsePattern': ('CBSE board pattern', 'ಸಿಬಿಎಸ್‌ಇ ಮಾದರಿ'),
};

String tr(String key, Lang lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == Lang.kn ? v.$2 : v.$1;
}

const subjectNames = <String, (String, String)>{
  'physics': ('Physics', 'ಭೌತಶಾಸ್ತ್ರ'),
  'chemistry': ('Chemistry', 'ರಸಾಯನಶಾಸ್ತ್ರ'),
  'maths': ('Maths', 'ಗಣಿತ'),
  'biology': ('Biology', 'ಜೀವಶಾಸ್ತ್ರ'),
  'computer_science': ('Computer Science', 'ಗಣಕ ವಿಜ್ಞಾನ'),
  'electronics': ('Electronics', 'ಎಲೆಕ್ಟ್ರಾನಿಕ್ಸ್'),
  'statistics': ('Statistics', 'ಸಂಖ್ಯಾಶಾಸ್ತ್ರ'),
  'accountancy': ('Accountancy', 'ಲೆಕ್ಕಶಾಸ್ತ್ರ'),
  'business_studies': ('Business Studies', 'ವ್ಯವಹಾರ ಅಧ್ಯಯನ'),
  'economics': ('Economics', 'ಅರ್ಥಶಾಸ್ತ್ರ'),
  'english': ('English', 'ಇಂಗ್ಲಿಷ್'),
};

/// "1st PUC" on Karnataka PU boards, "Class 11" on CBSE boards.
String yearLabel(String year, String board, Lang l) => board == 'cbse'
    ? (year == 'puc1' ? (l == Lang.kn ? '11ನೇ ತರಗತಿ' : 'Class 11') : (l == Lang.kn ? '12ನೇ ತರಗತಿ' : 'Class 12'))
    : (year == 'puc1' ? (l == Lang.kn ? 'ಪ್ರಥಮ ಪಿಯುಸಿ' : '1st PUC') : (l == Lang.kn ? 'ದ್ವಿತೀಯ ಪಿಯುಸಿ' : '2nd PUC'));

String subjectName(String s, Lang l) => l == Lang.kn ? (subjectNames[s]?.$2 ?? s) : (subjectNames[s]?.$1 ?? s);
