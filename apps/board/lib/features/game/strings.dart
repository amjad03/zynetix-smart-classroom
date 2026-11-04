import '../../engine/model.dart';

/// Text of the game hub and challenge blocks, in English and Kannada (Kannada to be reviewed by a
/// native speaker, like the content).
const _s = <String, (String, String)>{
  // Challenge block
  'challenge': ('Challenge', 'ಸವಾಲು'),
  'target': ('Target', 'ಗುರಿ'),
  'lockIn': ('Lock it in', 'ಖಚಿತಪಡಿಸಿ'),
  'triesLeft': ('tries left', 'ಪ್ರಯತ್ನಗಳು ಉಳಿದಿವೆ'),
  'tooHigh': ('Too high', 'ತುಂಬಾ ಹೆಚ್ಚು'),
  'tooLow': ('Too low', 'ತುಂಬಾ ಕಡಿಮೆ'),
  'hit': ('Bullseye!', 'ಗುರಿ ಮುಟ್ಟಿದಿರಿ!'),
  'timeUp': ('Time up: that try is lost', 'ಸಮಯ ಮುಗಿಯಿತು: ಆ ಪ್ರಯತ್ನ ಹೋಯಿತು'),
  'hint': ('Hint', 'ಸುಳಿವು'),
  'revealSolution': ('Show the solution', 'ಪರಿಹಾರ ತೋರಿಸಿ'),
  'solution': ('Solution', 'ಪರಿಹಾರ'),
  'whyItWorks': ('Why it works', 'ಏಕೆ ಸರಿ'),
  'playAgain': ('Play again', 'ಮತ್ತೆ ಆಡಿ'),
  'outOfTries': ('Out of tries. Here is how to hit it.', 'ಪ್ರಯತ್ನಗಳು ಮುಗಿದಿವೆ. ಗುರಿ ಮುಟ್ಟುವುದು ಹೀಗೆ.'),
  'stars': ('stars', 'ನಕ್ಷತ್ರಗಳು'),
  'turn': ('Turn', 'ಸರದಿ'),
  'wholeClass': ('Whole class', 'ಇಡೀ ತರಗತಿ'),
  'setSliders': ('Work it out, set the sliders, then lock it in. The result shows only after you lock in.', 'ಲೆಕ್ಕ ಹಾಕಿ, ಸ್ಲೈಡರ್‌ಗಳನ್ನು ಹೊಂದಿಸಿ, ನಂತರ ಖಚಿತಪಡಿಸಿ. ಫಲಿತಾಂಶ ಆಮೇಲೆ ಮಾತ್ರ ಕಾಣುತ್ತದೆ.'),
  'youGot': ('You got', 'ನಿಮಗೆ ಬಂದದ್ದು'),
  // Hub
  'gameHub': ('Game Zone', 'ಆಟದ ವಲಯ'),
  'gameHubSub': ('Missions, boss battles, badges', 'ಮಿಷನ್‌ಗಳು, ಬಾಸ್ ಕದನ, ಬ್ಯಾಡ್ಜ್‌ಗಳು'),
  'missions': ('Missions', 'ಮಿಷನ್‌ಗಳು'),
  'badges': ('Badges', 'ಬ್ಯಾಡ್ಜ್‌ಗಳು'),
  'league': ('League', 'ಲೀಗ್'),
  'points': ('points', 'ಅಂಕಗಳು'),
  'bossBattle': ('Boss battle', 'ಬಾಸ್ ಕದನ'),
  'bossBattleSub': ('A chapter test: every right answer hits the boss', 'ಅಧ್ಯಾಯ ಪರೀಕ್ಷೆ: ಪ್ರತಿ ಸರಿಯುತ್ತರ ಬಾಸ್‌ಗೆ ಹೊಡೆತ'),
  'bossName': ('Guardian of', 'ರಕ್ಷಕ:'),
  'bossBeaten': ('Boss beaten', 'ಬಾಸ್ ಸೋತಿದೆ'),
  'bossHealth': ('Boss health', 'ಬಾಸ್ ಶಕ್ತಿ'),
  'victory': ('Victory! The class beat the boss', 'ಗೆಲುವು! ತರಗತಿ ಬಾಸ್‌ನನ್ನು ಸೋಲಿಸಿತು'),
  'bossEscaped': ('The boss escaped. Revise and try again!', 'ಬಾಸ್ ತಪ್ಪಿಸಿಕೊಂಡ. ಪುನರಾವರ್ತಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ!'),
  'fight': ('Fight', 'ಹೋರಾಡಿ'),
  'teams': ('Teams', 'ತಂಡಗಳು'),
  'rollCall': ('Roll call', 'ರೋಲ್ ಕರೆ'),
  'noPacks': ('No chapters installed for this subject yet.', 'ಈ ವಿಷಯಕ್ಕೆ ಇನ್ನೂ ಅಧ್ಯಾಯಗಳಿಲ್ಲ.'),
  'notEnoughQuestions': ('This chapter needs more questions for a boss battle.', 'ಬಾಸ್ ಕದನಕ್ಕೆ ಈ ಅಧ್ಯಾಯದಲ್ಲಿ ಹೆಚ್ಚು ಪ್ರಶ್ನೆಗಳು ಬೇಕು.'),
  'sectionBadges': ('Class badges', 'ತರಗತಿ ಬ್ಯಾಡ್ಜ್‌ಗಳು'),
  'rollBadges': ('Roll numbers', 'ರೋಲ್ ಸಂಖ್ಯೆಗಳು'),
  'noRolls': ('No named answers yet. Use roll call or hands-up in a quiz to start.', 'ಇನ್ನೂ ರೋಲ್ ಸಂಖ್ಯೆಯ ಉತ್ತರಗಳಿಲ್ಲ. ರಸಪ್ರಶ್ನೆಯಲ್ಲಿ ರೋಲ್ ಕರೆ ಬಳಸಿ.'),
  'dayStreak': ('day streak', 'ದಿನಗಳ ಸರಣಿ'),
  'bestStreak': ('best run', 'ಅತ್ಯುತ್ತಮ ಸರಣಿ'),
  'inARow': ('in a row', 'ಸತತವಾಗಿ'),
  'offlineLeague': ('Offline: this section only', 'ಆಫ್‌ಲೈನ್: ಈ ವಿಭಾಗ ಮಾತ್ರ'),
  'leagueNote': ('Points: 10 per right answer, 15 per challenge star, streak bonuses, 50 per boss.', 'ಅಂಕಗಳು: ಪ್ರತಿ ಸರಿಯುತ್ತರಕ್ಕೆ 10, ಸವಾಲಿನ ನಕ್ಷತ್ರಕ್ಕೆ 15, ಸರಣಿ ಬೋನಸ್, ಬಾಸ್‌ಗೆ 50.'),
  'you': ('This section', 'ಈ ವಿಭಾಗ'),
  'locked': ('Not yet', 'ಇನ್ನೂ ಇಲ್ಲ'),
  // Badges
  'b.first': ('First right answer', 'ಮೊದಲ ಸರಿಯುತ್ತರ'),
  'b.streak3': ('Hat-trick: 3 in a row', 'ಹ್ಯಾಟ್ರಿಕ್: ಸತತ 3'),
  'b.streak5': ('On fire: 5 in a row', 'ಬೆಂಕಿ: ಸತತ 5'),
  'b.streak10': ('Unstoppable: 10 in a row', 'ತಡೆಯಲಾಗದು: ಸತತ 10'),
  'b.sharp10': ('Sharp: 10 right', 'ಚುರುಕು: 10 ಸರಿ'),
  'b.sharp50': ('Scholar: 50 right', 'ವಿದ್ವಾಂಸ: 50 ಸರಿ'),
  'b.master': ('Topic master', 'ವಿಷಯ ಪರಿಣತ'),
  'b.comeback': ('Comeback: wrong, then 3 right', 'ಪುನರಾಗಮನ: ತಪ್ಪು, ನಂತರ 3 ಸರಿ'),
  'b.ace': ('Ace: a 3-star challenge', 'ಏಸ್: 3-ನಕ್ಷತ್ರ ಸವಾಲು'),
  'b.days3': ('3 days running', 'ಸತತ 3 ದಿನ'),
  'b.week': ('A full week', 'ಪೂರ್ಣ ವಾರ'),
  'b.boss': ('Boss slayer', 'ಬಾಸ್ ವಿಜಯಿ'),
  'b.stars30': ('Star collector: 30 stars', 'ನಕ್ಷತ್ರ ಸಂಗ್ರಾಹಕ: 30'),
  'b.everyone': ('Everyone plays: 80% of rolls answered', 'ಎಲ್ಲರೂ ಆಡುತ್ತಾರೆ: 80% ರೋಲ್‌ಗಳು'),
  'b.hundred': ('Century: 100 right', 'ಶತಕ: 100 ಸರಿ'),
};

String gt(String key, Lang lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == Lang.kn ? v.$2 : v.$1;
}
