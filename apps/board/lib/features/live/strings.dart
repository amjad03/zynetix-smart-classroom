import '../../engine/model.dart';

/// Text for capturing every student's answer (hands-up grid, phones, paper marks), in English
/// and Kannada. Kannada to be checked by a native speaker, like the rest of the board.
const _s = <String, (String, String)>{
  // Hands up
  'hands': ('Hands up', 'ಕೈ ಎತ್ತಿ'),
  'handsWho': ('Who got it wrong?', 'ಯಾರು ತಪ್ಪು ಉತ್ತರಿಸಿದರು?'),
  'handsHelp': ('Tap the roll numbers who got it wrong. Everyone else counts as right.', 'ತಪ್ಪು ಉತ್ತರಿಸಿದವರ ರೋಲ್ ಸಂಖ್ಯೆ ಒತ್ತಿ. ಉಳಿದವರೆಲ್ಲ ಸರಿ.'),
  'handsHelpRight': ('Tap the roll numbers who got it right. Everyone else counts as wrong.', 'ಸರಿ ಉತ್ತರಿಸಿದವರ ರೋಲ್ ಸಂಖ್ಯೆ ಒತ್ತಿ. ಉಳಿದವರೆಲ್ಲ ತಪ್ಪು.'),
  'handsHelpAbsent': ('Tap the roll numbers who are absent today.', 'ಇಂದು ಗೈರಾದವರ ರೋಲ್ ಸಂಖ್ಯೆ ಒತ್ತಿ.'),
  'tapWrong': ('Tap = wrong', 'ಒತ್ತಿದರೆ = ತಪ್ಪು'),
  'tapRight': ('Tap = right', 'ಒತ್ತಿದರೆ = ಸರಿ'),
  'tapAbsent': ('Tap = absent', 'ಒತ್ತಿದರೆ = ಗೈರು'),
  'save': ('Save', 'ಉಳಿಸಿ'),
  'saved': ('Saved', 'ಉಳಿಸಲಾಗಿದೆ'),
  'rightCount': ('right', 'ಸರಿ'),
  'wrongCount': ('wrong', 'ತಪ್ಪು'),
  'absentCount': ('absent', 'ಗೈರು'),
  'perRoll': ('By roll number', 'ರೋಲ್ ಸಂಖ್ಯೆ ಪ್ರಕಾರ'),
  'perOption': ('Count hands per option', 'ಪ್ರತಿ ಆಯ್ಕೆಗೆ ಕೈಗಳನ್ನು ಎಣಿಸಿ'),
  'perOptionHelp': ('Ask "who chose A?" and so on. Tap + for each raised hand.', '"A ಆರಿಸಿದವರು ಯಾರು?" ಎಂದು ಕೇಳಿ. ಎತ್ತಿದ ಪ್ರತಿ ಕೈಗೆ + ಒತ್ತಿ.'),
  'handsSaved': ('Hands saved', 'ಕೈಗಳನ್ನು ಉಳಿಸಲಾಗಿದೆ'),
  // Phones
  'phones': ('Phone quiz', 'ಫೋನ್ ರಸಪ್ರಶ್ನೆ'),
  'phonesSub': ('Every student answers on a phone, over the board\'s own Wi-Fi', 'ಪ್ರತಿ ವಿದ್ಯಾರ್ಥಿ ಫೋನಿನಲ್ಲಿ ಉತ್ತರಿಸುತ್ತಾರೆ, ಬೋರ್ಡ್‌ನ ವೈ-ಫೈ ಮೂಲಕ'),
  'startPhones': ('Start phone quiz', 'ಫೋನ್ ರಸಪ್ರಶ್ನೆ ಪ್ರಾರಂಭಿಸಿ'),
  'scanToJoin': ('Scan, or open this address on the same Wi-Fi', 'ಸ್ಕ್ಯಾನ್ ಮಾಡಿ, ಅಥವಾ ಅದೇ ವೈ-ಫೈನಲ್ಲಿ ಈ ವಿಳಾಸ ತೆರೆಯಿರಿ'),
  'roomCode': ('Room code', 'ಕೊಠಡಿ ಕೋಡ್'),
  'joined': ('phones joined', 'ಫೋನ್‌ಗಳು ಸೇರಿವೆ'),
  'answered': ('answered', 'ಉತ್ತರಿಸಿದ್ದಾರೆ'),
  'openQuestion': ('Send question to phones', 'ಪ್ರಶ್ನೆಯನ್ನು ಫೋನ್‌ಗಳಿಗೆ ಕಳುಹಿಸಿ'),
  'noNetwork': ('No Wi-Fi network found. Connect the board to the classroom Wi-Fi or turn on its hotspot.', 'ವೈ-ಫೈ ಸಿಗಲಿಲ್ಲ. ಬೋರ್ಡ್ ಅನ್ನು ತರಗತಿಯ ವೈ-ಫೈಗೆ ಸಂಪರ್ಕಿಸಿ ಅಥವಾ ಹಾಟ್‌ಸ್ಪಾಟ್ ಆನ್ ಮಾಡಿ.'),
  'serverFailed': ('Could not start the phone quiz', 'ಫೋನ್ ರಸಪ್ರಶ್ನೆ ಪ್ರಾರಂಭಿಸಲಾಗಲಿಲ್ಲ'),
  'classResult': ('Class result', 'ತರಗತಿಯ ಫಲಿತಾಂಶ'),
  'noAnswers': ('No answers yet', 'ಇನ್ನೂ ಉತ್ತರಗಳಿಲ್ಲ'),
  'chooseTest': ('Choose a chapter', 'ಅಧ್ಯಾಯ ಆರಿಸಿ'),
  'questionsCount': ('questions', 'ಪ್ರಶ್ನೆಗಳು'),
  'testSize': ('Questions in the test', 'ಪರೀಕ್ಷೆಯ ಪ್ರಶ್ನೆಗಳು'),
  'noPacks': ('No chapters installed yet. They come with content updates.', 'ಇನ್ನೂ ಅಧ್ಯಾಯಗಳಿಲ್ಲ. ಅಪ್‌ಡೇಟ್‌ನಲ್ಲಿ ಬರುತ್ತವೆ.'),
  // Paper marks
  'paperMarks': ('Paper test marks', 'ಪತ್ರಿಕೆ ಪರೀಕ್ಷೆ ಅಂಕಗಳು'),
  'paperMarksSub': ('Enter each roll number\'s answers from a written test', 'ಲಿಖಿತ ಪರೀಕ್ಷೆಯಿಂದ ಪ್ರತಿ ರೋಲ್ ಸಂಖ್ಯೆಯ ಉತ್ತರಗಳನ್ನು ನಮೂದಿಸಿ'),
  'paperHelp': ('Tap a box: right, wrong, blank. "All right" fills a row.', 'ಚೌಕ ಒತ್ತಿ: ಸರಿ, ತಪ್ಪು, ಖಾಲಿ. "ಎಲ್ಲಾ ಸರಿ" ಸಾಲನ್ನು ತುಂಬುತ್ತದೆ.'),
  'allRight': ('All right', 'ಎಲ್ಲಾ ಸರಿ'),
  'printTest': ('Questions of this test', 'ಈ ಪರೀಕ್ಷೆಯ ಪ್ರಶ್ನೆಗಳು'),
  'saveMarks': ('Save marks', 'ಅಂಕಗಳನ್ನು ಉಳಿಸಿ'),
  'marksSaved': ('Marks saved', 'ಅಂಕಗಳನ್ನು ಉಳಿಸಲಾಗಿದೆ'),
  'entered': ('rolls entered', 'ರೋಲ್‌ಗಳು ನಮೂದಾಗಿವೆ'),
  'discard': ('Leave without saving?', 'ಉಳಿಸದೆ ಹೊರಡುವುದೇ?'),
  'leave': ('Leave', 'ಹೊರಡಿ'),
  'stay': ('Stay', 'ಇರಿ'),
  'q': ('Q', 'ಪ್ರ'),
};

String ltr(String key, Lang lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == Lang.kn ? v.$2 : v.$1;
}
