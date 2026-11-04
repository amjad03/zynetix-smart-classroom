import '../../engine/model.dart';

/// Text for the insight screens (re-teach, mastery map, exam readiness, today's plan,
/// worksheets) in English and Kannada. Kannada to be checked by a native speaker.
const _s = <String, (String, String)>{
  // Re-teach
  'reteachTitle': ('The class found this hard', 'ತರಗತಿಗೆ ಇದು ಕಷ್ಟವಾಯಿತು'),
  'reteachScore': ('right', 'ಸರಿ'),
  'missed': ('Missed', 'ತಪ್ಪಿದ ಪ್ರಶ್ನೆಗಳು'),
  'reteach': ('Re-teach another way', 'ಬೇರೆ ರೀತಿಯಲ್ಲಿ ಮತ್ತೆ ಕಲಿಸಿ'),
  'reteachShort': ('Re-teach', 'ಮತ್ತೆ ಕಲಿಸಿ'),
  'pairUp': ('Pair up', 'ಜೋಡಿ ಮಾಡಿ'),
  'pairsHint': ('Each stuck roll number sits with a buddy who has it', 'ಕಷ್ಟಪಡುತ್ತಿರುವ ಪ್ರತಿ ಕ್ರಮಸಂಖ್ಯೆ ತಿಳಿದ ಗೆಳೆಯನೊಂದಿಗೆ ಕುಳಿತುಕೊಳ್ಳಲಿ'),
  'noPairs': ('No roll numbers to pair yet: use Roll call in quizzes', 'ಇನ್ನೂ ಜೋಡಿ ಇಲ್ಲ: ರಸಪ್ರಶ್ನೆಯಲ್ಲಿ ರೋಲ್ ಕಾಲ್ ಬಳಸಿ'),
  'carryOn': ('Carry on', 'ಮುಂದುವರಿಸಿ'),
  'anotherWay': ('Let us see it another way', 'ಇದನ್ನು ಬೇರೆ ರೀತಿಯಲ್ಲಿ ನೋಡೋಣ'),
  'backToLesson': ('Back to the lesson', 'ಪಾಠಕ್ಕೆ ಹಿಂತಿರುಗಿ'),
  'roll': ('Roll', 'ಕ್ರಮಸಂಖ್ಯೆ'),
  'with': ('with', 'ಜೊತೆ'),
  // Mastery map
  'masteryMap': ('Mastery map', 'ಕಲಿಕೆಯ ನಕ್ಷೆ'),
  'masteryMapSub': ('Who knows what, topic by topic', 'ಯಾರಿಗೆ ಏನು ಗೊತ್ತು, ವಿಷಯವಾರು'),
  'allSubjects': ('All', 'ಎಲ್ಲಾ'),
  'allChapters': ('All chapters', 'ಎಲ್ಲಾ ಅಧ್ಯಾಯಗಳು'),
  'onlyWeak': ('Only weak', 'ದುರ್ಬಲ ಮಾತ್ರ'),
  'onlyData': ('Only with answers', 'ಉತ್ತರ ಇರುವವು ಮಾತ್ರ'),
  'topic': ('Topic', 'ವಿಷಯ'),
  'classCol': ('Class', 'ತರಗತಿ'),
  'noTopics': ('No topics match these filters', 'ಈ ಆಯ್ಕೆಗೆ ಯಾವ ವಿಷಯವೂ ಇಲ್ಲ'),
  'mastered': ('Mastered', 'ಕಲಿತಿದ್ದಾರೆ'),
  'learning': ('Learning', 'ಕಲಿಯುತ್ತಿದ್ದಾರೆ'),
  'stuck': ('Stuck', 'ಕಷ್ಟಪಡುತ್ತಿದ್ದಾರೆ'),
  'unknown': ('Not enough answers', 'ಸಾಕಷ್ಟು ಉತ್ತರಗಳಿಲ್ಲ'),
  'teachNow': ('Teach this now', 'ಈಗ ಇದನ್ನು ಕಲಿಸಿ'),
  'noLesson': ('No lesson for this topic yet', 'ಈ ವಿಷಯಕ್ಕೆ ಇನ್ನೂ ಪಾಠವಿಲ್ಲ'),
  'answers': ('answers', 'ಉತ್ತರಗಳು'),
  'nobody': ('Nobody yet', 'ಇನ್ನೂ ಯಾರೂ ಇಲ್ಲ'),
  'buddies': ('Buddies', 'ಜೋಡಿಗಳು'),
  // Roll report
  'rollReport': ('Roll report', 'ಕ್ರಮಸಂಖ್ಯೆ ವರದಿ'),
  'strongTopics': ('Strong topics', 'ಬಲವಾದ ವಿಷಯಗಳು'),
  'weakTopics': ('Needs help with', 'ಸಹಾಯ ಬೇಕಾದ ವಿಷಯಗಳು'),
  'trend': ('Week by week', 'ವಾರದಿಂದ ವಾರಕ್ಕೆ'),
  'noAnswersYet': ('No answers from this roll number yet', 'ಈ ಕ್ರಮಸಂಖ್ಯೆಯಿಂದ ಇನ್ನೂ ಉತ್ತರಗಳಿಲ್ಲ'),
  'overall': ('Overall', 'ಒಟ್ಟಾರೆ'),
  'topicsWithAnswers': ('topics with answers', 'ಉತ್ತರಗಳಿರುವ ವಿಷಯಗಳು'),
  'practiceSheet': ('Practice sheet', 'ಅಭ್ಯಾಸ ಪತ್ರ'),
  // Exam readiness
  'examReadiness': ('Exam readiness', 'ಪರೀಕ್ಷಾ ಸಿದ್ಧತೆ'),
  'estimateNote': (
    'An estimate from answers given on this board, not a rank prediction. Coverage is the share of the exam\'s topics with answers.',
    'ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ನೀಡಿದ ಉತ್ತರಗಳಿಂದ ಅಂದಾಜು, ರ‍್ಯಾಂಕ್ ಮುನ್ಸೂಚನೆ ಅಲ್ಲ. ವ್ಯಾಪ್ತಿ ಎಂದರೆ ಉತ್ತರಗಳಿರುವ ಪರೀಕ್ಷಾ ವಿಷಯಗಳ ಪಾಲು.',
  ),
  'bandReady': ('Exam-ready', 'ಪರೀಕ್ಷೆಗೆ ಸಿದ್ಧ'),
  'bandOnTrack': ('On track', 'ಸರಿಯಾದ ದಾರಿಯಲ್ಲಿ'),
  'bandNeedsWork': ('Needs work', 'ಇನ್ನಷ್ಟು ಶ್ರಮ ಬೇಕು'),
  'bandNoData': ('Not enough data', 'ಸಾಕಷ್ಟು ಮಾಹಿತಿ ಇಲ್ಲ'),
  'coverage': ('coverage', 'ವ್ಯಾಪ್ತಿ'),
  'estimate': ('Estimate', 'ಅಂದಾಜು'),
  // Today's plan
  'todayPlan': ('Next period', 'ಮುಂದಿನ ಅವಧಿ'),
  'revise': ('Revise', 'ಪುನರಾವರ್ತಿಸಿ'),
  'thenTeach': ('then', 'ನಂತರ'),
  'min': ('min', 'ನಿಮಿಷ'),
  'fromTimetable': ('From the timetable', 'ವೇಳಾಪಟ್ಟಿಯಿಂದ'),
  'fromLastChapter': ('Continues the last chapter', 'ಕೊನೆಯ ಅಧ್ಯಾಯದಿಂದ ಮುಂದುವರಿಕೆ'),
  'startPlan': ('Start', 'ಪ್ರಾರಂಭಿಸಿ'),
  'reviseDone': ('Done: start the new topic', 'ಮುಗಿಯಿತು: ಹೊಸ ವಿಷಯ ಪ್ರಾರಂಭಿಸಿ'),
  'nothingPlanned': ('Nothing to plan yet', 'ಇನ್ನೂ ಯೋಜನೆ ಇಲ್ಲ'),
  // Worksheet
  'worksheet': ('Homework sheet', 'ಮನೆಗೆಲಸ ಪತ್ರ'),
  'worksheetSub': ('8–10 questions on the class\'s weak topics, with an answer key', 'ತರಗತಿಯ ದುರ್ಬಲ ವಿಷಯಗಳ ಮೇಲೆ 8–10 ಪ್ರಶ್ನೆಗಳು, ಉತ್ತರ ಕೀಲಿಯೊಂದಿಗೆ'),
  'wholeClass': ('Whole class', 'ಇಡೀ ತರಗತಿ'),
  'print': ('Print', 'ಮುದ್ರಿಸಿ'),
  'share': ('Share', 'ಹಂಚಿಕೊಳ್ಳಿ'),
  'questions': ('questions', 'ಪ್ರಶ್ನೆಗಳು'),
  'noQuestions': ('No questions available yet', 'ಇನ್ನೂ ಪ್ರಶ್ನೆಗಳಿಲ್ಲ'),
  'stuckRolls': ('Stuck roll numbers', 'ಕಷ್ಟಪಡುತ್ತಿರುವ ಕ್ರಮಸಂಖ್ಯೆಗಳು'),
  'pdfEnglish': ('Printed in English', 'ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ ಮುದ್ರಿಸಲಾಗುತ್ತದೆ'),
  'printFailed': ('Could not print or share on this device', 'ಈ ಸಾಧನದಲ್ಲಿ ಮುದ್ರಿಸಲು ಅಥವಾ ಹಂಚಲು ಆಗಲಿಲ್ಲ'),
};

/// Insight text in [lang]; the key itself when missing.
String it(String key, Lang lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == Lang.kn ? v.$2 : v.$1;
}
