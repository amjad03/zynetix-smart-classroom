import '../../engine/model.dart';

/// Text of scene controls and activities, in English and Kannada (Kannada to be reviewed by a
/// native speaker, like the content).
const _s = <String, (String, String)>{
  // Time bar
  'play': ('Play', 'ಪ್ರಾರಂಭಿಸಿ'),
  'pause': ('Pause', 'ವಿರಾಮ'),
  'step': ('Step', 'ಒಂದು ಹೆಜ್ಜೆ'),
  'reset': ('Reset', 'ಮರುಹೊಂದಿಸಿ'),
  'speed': ('Speed', 'ವೇಗ'),
  'time': ('Time', 'ಸಮಯ'),
  'on': ('On', 'ಆನ್'),
  'off': ('Off', 'ಆಫ್'),
  'dragPoint': ('Drag the glowing points', 'ಹೊಳೆಯುವ ಬಿಂದುಗಳನ್ನು ಎಳೆಯಿರಿ'),
  // Activities
  'activity': ('Activity', 'ಚಟುವಟಿಕೆ'),
  'check': ('Check', 'ಪರಿಶೀಲಿಸಿ'),
  'showAnswer': ('Show answer', 'ಉತ್ತರ ತೋರಿಸಿ'),
  'resetActivity': ('Start again', 'ಮತ್ತೆ ಪ್ರಾರಂಭಿಸಿ'),
  'allRight': ('All correct!', 'ಎಲ್ಲವೂ ಸರಿ!'),
  'someWrong': ('right. Fix the red ones and check again.', 'ಸರಿ. ಕೆಂಪು ಬಣ್ಣದವನ್ನು ಸರಿಪಡಿಸಿ ಮತ್ತೆ ಪರಿಶೀಲಿಸಿ.'),
  'notDone': ('Place every item first.', 'ಮೊದಲು ಎಲ್ಲವನ್ನೂ ಇರಿಸಿ.'),
  'answerShown': ('Here is the answer.', 'ಉತ್ತರ ಇಲ್ಲಿದೆ.'),
  'why': ('Why', 'ಏಕೆ'),
  'of': ('of', 'ರಲ್ಲಿ'),
  'tapThenPlace': ('Drag an item, or tap it and then tap where it goes.', 'ಐಟಂ ಅನ್ನು ಎಳೆಯಿರಿ, ಅಥವಾ ಅದನ್ನು ತಟ್ಟಿ ನಂತರ ಅದು ಹೋಗುವ ಜಾಗವನ್ನು ತಟ್ಟಿ.'),
  'tapToOrder': ('Drag the cards, or use the arrows, to put them in order.', 'ಕಾರ್ಡ್‌ಗಳನ್ನು ಎಳೆದು, ಅಥವಾ ಬಾಣಗಳಿಂದ, ಕ್ರಮದಲ್ಲಿ ಇಡಿ.'),
  'tapToMatch': ('Tap a card on the left, then its partner on the right.', 'ಎಡಭಾಗದ ಕಾರ್ಡ್ ತಟ್ಟಿ, ನಂತರ ಬಲಭಾಗದ ಅದರ ಜೋಡಿಯನ್ನು ತಟ್ಟಿ.'),
  'tapSpots': ('Tap the right places, then check.', 'ಸರಿಯಾದ ಜಾಗಗಳನ್ನು ತಟ್ಟಿ, ನಂತರ ಪರಿಶೀಲಿಸಿ.'),
  'tapBlank': ('Tap a blank, then choose its word.', 'ಖಾಲಿ ಜಾಗವನ್ನು ತಟ್ಟಿ, ನಂತರ ಅದರ ಪದವನ್ನು ಆರಿಸಿ.'),
  'moveUp': ('Move up', 'ಮೇಲೆ ಸರಿಸಿ'),
  'moveDown': ('Move down', 'ಕೆಳಗೆ ಸರಿಸಿ'),
  'items': ('Items', 'ಐಟಂಗಳು'),
  'placed': ('placed', 'ಇರಿಸಲಾಗಿದೆ'),
  'dropHere': ('Drop here', 'ಇಲ್ಲಿ ಇಡಿ'),
  'checkHint': ('Check marks each item right or wrong.', 'ಪರಿಶೀಲಿಸಿ ಪ್ರತಿ ಐಟಂ ಸರಿ ಅಥವಾ ತಪ್ಪು ಎಂದು ತೋರಿಸುತ್ತದೆ.'),
  'kind.sort': ('Sort', 'ವಿಂಗಡಿಸಿ'),
  'kind.order': ('Order', 'ಕ್ರಮಗೊಳಿಸಿ'),
  'kind.match': ('Match', 'ಹೊಂದಿಸಿ'),
  'kind.label': ('Label', 'ಹೆಸರಿಸಿ'),
  'kind.hotspot': ('Find', 'ಹುಡುಕಿ'),
  'kind.fill': ('Fill in', 'ತುಂಬಿಸಿ'),
};

/// The string [key] in [lang] (English when Kannada is missing).
String st(String key, Lang lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == Lang.kn ? v.$2 : v.$1;
}

/// Every key, for tests.
Iterable<String> get sceneStringKeys => _s.keys;
