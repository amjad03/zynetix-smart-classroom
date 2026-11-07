import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../engine/model.dart';

/// The school's own records on this board, kept on the device so everything works offline:
/// the teachers who use it (name and initials only), the timetable the school sets, where each
/// lesson was left, finished classes, quiz and test results, teams and the class plan.
///
/// Students are only ever roll numbers: no names, photos or anything else that identifies them.
class SchoolStore extends ChangeNotifier {
  SchoolStore({this.file, DateTime Function()? now}) : now = now ?? DateTime.now {
    _load();
  }

  /// Where the records are kept; null keeps them in memory (tests, previews).
  final File? file;
  final DateTime Function() now;
  Map<String, dynamic> _j = {};

  void _load() {
    final f = file;
    if (f == null || !f.existsSync()) return;
    try {
      _j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      // A torn file after a power cut: keep the last good copy if there is one.
      final bak = File('${f.path}.bak');
      if (bak.existsSync()) {
        try {
          _j = jsonDecode(bak.readAsStringSync()) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
  }

  void _save() {
    final f = file;
    if (f != null) {
      try {
        f.parent.createSync(recursive: true);
        if (f.existsSync()) f.copySync('${f.path}.bak');
        final tmp = File('${f.path}.tmp')..writeAsStringSync(jsonEncode(_j), flush: true);
        tmp.renameSync(f.path);
      } catch (e) {
        debugPrint('School records not saved: $e');
      }
    }
    notifyListeners();
  }

  /// Replaces every record (tests, the screenshot harness).
  void seed(Map<String, dynamic> j) {
    _j = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
    _save();
  }

  T? _get<T>(String k) => _j[k] as T?;
  List<Map<String, dynamic>> _list(String k) => [for (final e in (_j[k] as List?) ?? const []) (e as Map).cast<String, dynamic>()];

  // ---- First open, guide and the simple/all switch ----

  bool get setUp => _get<bool>('setUp') ?? false;
  Future<void> finishSetUp() async {
    _j['setUp'] = true;
    _save();
  }

  bool get tourDone => _get<bool>('tourDone') ?? false;
  void setTourDone(bool v) {
    _j['tourDone'] = v;
    _save();
  }

  bool get guideMuted => _get<bool>('guideMuted') ?? false;
  void setGuideMuted(bool v) {
    _j['guideMuted'] = v;
    _save();
  }

  /// Simple mode is the default; the switch reveals every tool.
  bool get showAll => _get<bool>('showAll') ?? false;
  void setShowAll(bool v) {
    _j['showAll'] = v;
    _save();
  }

  /// Who to call from "What do I do now?" (set in Settings).
  String get helpContact => _get<String>('helpContact') ?? '';
  void setHelpContact(String v) {
    _j['helpContact'] = v.trim();
    _save();
  }

  // ---- Teachers ----

  List<Teacher> get teachers => [for (final t in _list('teachers')) Teacher.fromJson(t)];
  Teacher? teacher(String? id) => teachers.where((t) => t.id == id).firstOrNull;

  /// The teacher who tapped their card on this board today.
  /// Signing in lasts for the day: the next morning starts at "Who's teaching today?".
  Teacher? get current => _get<String>('currentDay') == dayKey(now()) ? teacher(_get<String>('current')) : null;
  void signIn(String? id) {
    _j['current'] = id;
    _j['currentDay'] = dayKey(now());
    _save();
  }

  /// The school can ask for a PIN on each teacher card. Off by default.
  bool get pinsOn => _get<bool>('pinsOn') ?? false;
  void setPinsOn(bool v) {
    _j['pinsOn'] = v;
    _save();
  }

  Teacher addTeacher(String name, {String? initials, String? pin}) {
    final list = _list('teachers');
    final t = Teacher(
      id: 't${now().microsecondsSinceEpoch}',
      name: name.trim(),
      initials: (initials?.trim().isNotEmpty ?? false) ? initials!.trim().toUpperCase() : Teacher.initialsOf(name),
      colour: list.length % Teacher.colours.length,
      pinHash: (pin?.isNotEmpty ?? false) ? Teacher.hash(pin!) : null,
    );
    _j['teachers'] = [...list, t.toJson()];
    _save();
    return t;
  }

  void updateTeacher(Teacher t) {
    _j['teachers'] = [for (final e in teachers) (e.id == t.id ? t : e).toJson()];
    _save();
  }

  void removeTeacher(String id) {
    _j['teachers'] = [for (final e in teachers) if (e.id != id) e.toJson()];
    if (_get<String>('current') == id) _j['current'] = null;
    _j['periods'] = [for (final p in periods) (p.teacherId == id ? p.copyWith(teacherId: '') : p).toJson()];
    _save();
  }

  // ---- Timetable ----

  List<Period> get periods => [for (final p in _list('periods')) Period.fromJson(p)]..sort((a, b) => a.start.compareTo(b.start));
  void setPeriods(List<Period> ps) {
    _j['periods'] = [for (final p in ps) p.toJson()];
    _save();
  }

  /// Today's periods, in order.
  List<Period> today([DateTime? at]) {
    final d = (at ?? now()).weekday;
    return [for (final p in periods) if (p.days.contains(d)) p];
  }

  /// The period on now, or the next one today (for [teacherId] when given).
  Period? classNow({String? teacherId, DateTime? at}) {
    final t = at ?? now();
    final mins = t.hour * 60 + t.minute;
    final list = [for (final p in today(t)) if (teacherId == null || p.teacherId == null || p.teacherId!.isEmpty || p.teacherId == teacherId) p];
    return list.where((p) => p.startMin <= mins && mins < p.endMin).firstOrNull ?? list.where((p) => p.startMin > mins).firstOrNull;
  }

  // ---- Where each lesson was left ----

  int stepFor(String topicId) => (_get<Map>('progress')?[topicId] as num?)?.toInt() ?? 0;
  void setStep(String topicId, int step) {
    final m = Map<String, dynamic>.from(_get<Map>('progress') ?? const {});
    if (m[topicId] == step) return;
    m[topicId] = step;
    _j['progress'] = m;
    _save();
  }

  // ---- Finished classes ----

  List<ClassRecord> get history => [for (final r in _list('history')) ClassRecord.fromJson(r)].reversed.toList();
  void addClass(ClassRecord r) {
    _j['history'] = [..._list('history'), r.toJson()];
    _save();
  }

  void updateClass(ClassRecord r) {
    _j['history'] = [for (final e in _list('history')) e['id'] == r.id ? r.toJson() : e];
    _save();
  }

  void removeClass(String id) {
    _j['history'] = [for (final e in _list('history')) if (e['id'] != id) e];
    _save();
  }

  // ---- Class quiz results (by roll number) ----

  List<QuizResult> get quizzes => [for (final r in _list('quizzes')) QuizResult.fromJson(r)];
  void addQuiz(QuizResult r) {
    _j['quizzes'] = [..._list('quizzes'), r.toJson()];
    _save();
  }

  void removeQuiz(String id) {
    _j['quizzes'] = [for (final e in _list('quizzes')) if (e['id'] != id) e];
    _save();
  }

  // ---- Mock test scores (by roll number) ----

  List<TestResult> get tests => [for (final r in _list('tests')) TestResult.fromJson(r)];
  void addTest(TestResult r) {
    _j['tests'] = [..._list('tests'), r.toJson()];
    _save();
  }

  void removeTest(String id) {
    _j['tests'] = [for (final e in _list('tests')) if (e['id'] != id) e];
    _save();
  }

  // ---- Teams: houses by roll range, XP and the class streak ----

  /// Four houses splitting the roll numbers until the school sets its own.
  int rollCount = 60;
  List<House> get houses {
    final l = _list('houses');
    return l.isEmpty ? House.defaults(rollCount) : [for (final h in l) House.fromJson(h)];
  }

  void setHouses(List<House> hs) {
    _j['houses'] = [for (final h in hs) h.toJson()];
    _save();
  }

  void addXp(int house, int xp) {
    final hs = houses;
    if (house < 0 || house >= hs.length) return;
    hs[house] = hs[house].copyWith(xp: hs[house].xp + xp);
    setHouses(hs);
    markStreakDay();
  }

  /// Days (yyyy-mm-dd) the class did a quiz or test: the class streak.
  List<String> get streakDays => [for (final d in (_j['streak'] as List?) ?? const []) '$d'];
  void markStreakDay([DateTime? at]) {
    final d = dayKey(at ?? now());
    if (streakDays.contains(d)) return;
    _j['streak'] = [...streakDays, d];
    _save();
  }

  /// School days in a row (Sundays skipped) up to today or yesterday.
  int get streak {
    final set = streakDays.toSet();
    var d = now();
    if (!set.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (true) {
      if (d.weekday == DateTime.sunday) {
        d = d.subtract(const Duration(days: 1));
        continue;
      }
      if (!set.contains(dayKey(d))) break;
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---- Class plan ----

  DateTime? get examDate => DateTime.tryParse(_get<String>('examDate') ?? '');
  String get examName => _get<String>('examName') ?? '';
  int get revisionWeeks => _get<int>('revisionWeeks') ?? 3;
  void setPlan({DateTime? examDate, String? examName, int? revisionWeeks}) {
    if (examDate != null) _j['examDate'] = dayKey(examDate);
    if (examName != null) _j['examName'] = examName;
    if (revisionWeeks != null) _j['revisionWeeks'] = revisionWeeks;
    _save();
  }

  // ---- Formula drill: formulas the class has recalled ----

  Set<String> get drilled => {for (final d in (_j['drilled'] as List?) ?? const []) '$d'};
  void setDrilled(String id, bool known) {
    final s = drilled;
    known ? s.add(id) : s.remove(id);
    _j['drilled'] = s.toList();
    _save();
  }

  // ---- Undo: the last things done on this board, newest last (kept while the app runs) ----

  final List<UndoItem> _undo = [];
  UndoItem? get lastUndo => _undo.lastOrNull;
  void pushUndo(L10n what, VoidCallback revert) {
    _undo.add(UndoItem(what, revert));
    if (_undo.length > 50) _undo.removeAt(0);
    notifyListeners();
  }

  /// Undoes the last action; false when there is nothing to undo.
  bool undo() {
    final u = _undo.isEmpty ? null : _undo.removeLast();
    if (u == null) return false;
    u.revert();
    notifyListeners();
    return true;
  }

  /// Forgets undo steps that belong to a screen that has closed. Screens call this from
  /// dispose (while the tree is locked), so listeners hear of it just after the frame.
  void dropUndo(bool Function(UndoItem) where) {
    final n = _undo.length;
    _undo.removeWhere(where);
    if (_undo.length != n) scheduleMicrotask(notifyListeners);
  }
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class UndoItem {
  UndoItem(this.what, this.revert);
  final L10n what;
  final VoidCallback revert;
}

/// A teacher who uses this board: a name and initials (a disc with the initials stands in for a
/// photo), and an optional PIN the school can turn on.
class Teacher {
  const Teacher({required this.id, required this.name, required this.initials, this.colour = 0, this.pinHash});
  final String id, name, initials;
  final int colour;
  final String? pinHash;

  static const colours = [0xFF2457E6, 0xFF00876A, 0xFF7A4FD6, 0xFF3C9A3C, 0xFFD55E00, 0xFFB4441B, 0xFF0E7490];
  int get colorValue => colours[colour % colours.length];

  /// "K. Meera" → "KM"; "Meera" → "ME".
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'[\s.]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// The name to greet: "K. Meera" → "Meera".
  String get firstName {
    final parts = name.trim().split(RegExp(r'[\s.]+')).where((p) => p.length > 1).toList();
    return parts.isEmpty ? name : parts.last;
  }

  static String hash(String pin) => sha256.convert(utf8.encode('zynetix-teacher:$pin')).toString();
  bool checkPin(String pin) => pinHash == null || hash(pin) == pinHash;

  Teacher copyWith({String? name, String? initials, String? pinHash, bool clearPin = false}) =>
      Teacher(id: id, name: name ?? this.name, initials: initials ?? this.initials, colour: colour, pinHash: clearPin ? null : (pinHash ?? this.pinHash));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'initials': initials, 'colour': colour, 'pin': ?pinHash};
  factory Teacher.fromJson(Map<String, dynamic> j) =>
      Teacher(id: j['id'] as String, name: j['name'] as String? ?? '', initials: j['initials'] as String? ?? '?', colour: (j['colour'] as num?)?.toInt() ?? 0, pinHash: j['pin'] as String?);
}

/// One period of the timetable the school sets: days, times, subject and (optionally) teacher.
class Period {
  const Period({required this.id, required this.start, required this.end, required this.subject, this.days = const [1, 2, 3, 4, 5, 6], this.teacherId, this.label = ''});
  final String id, start, end, subject;
  final List<int> days;
  final String? teacherId;

  /// The class, when it is not this board's section (e.g. "2nd PUC A").
  final String label;

  static int _min(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p.first) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  int get startMin => _min(start);
  int get endMin => _min(end);

  /// 9:45 (no leading zero, 12-hour as on a school timetable).
  static String clock(String hhmm) {
    final m = _min(hhmm);
    final h = m ~/ 60 % 12 == 0 ? 12 : m ~/ 60 % 12;
    return '$h:${(m % 60).toString().padLeft(2, '0')}';
  }

  Period copyWith({String? start, String? end, String? subject, List<int>? days, String? teacherId, String? label}) =>
      Period(id: id, start: start ?? this.start, end: end ?? this.end, subject: subject ?? this.subject, days: days ?? this.days, teacherId: teacherId ?? this.teacherId, label: label ?? this.label);

  Map<String, dynamic> toJson() => {'id': id, 'start': start, 'end': end, 'subject': subject, 'days': days, 'teacher': ?teacherId, 'label': label};
  factory Period.fromJson(Map<String, dynamic> j) => Period(
    id: j['id'] as String,
    start: j['start'] as String,
    end: j['end'] as String,
    subject: j['subject'] as String,
    days: [for (final d in (j['days'] as List?) ?? const [1, 2, 3, 4, 5, 6]) (d as num).toInt()],
    teacherId: j['teacher'] as String?,
    label: j['label'] as String? ?? '',
  );
}

/// A finished class: what was covered, homework and attendance by roll number.
class ClassRecord {
  ClassRecord({
    required this.id,
    required this.at,
    required this.subject,
    required this.topicId,
    required this.topic,
    required this.chapter,
    required this.stepsSeen,
    required this.stepsTotal,
    required this.minutes,
    this.teacherId,
    this.teacherName = '',
    this.homework = '',
    this.absent = const [],
    this.rollCount = 0,
  });
  final String id, subject, topicId;
  final DateTime at;
  final L10n topic, chapter;
  final int stepsSeen, stepsTotal, minutes, rollCount;
  final String? teacherId;
  final String teacherName, homework;
  final List<int> absent;

  int get present => rollCount - absent.length;

  ClassRecord copyWith({String? homework, List<int>? absent}) => ClassRecord(
    id: id,
    at: at,
    subject: subject,
    topicId: topicId,
    topic: topic,
    chapter: chapter,
    stepsSeen: stepsSeen,
    stepsTotal: stepsTotal,
    minutes: minutes,
    teacherId: teacherId,
    teacherName: teacherName,
    homework: homework ?? this.homework,
    absent: absent ?? this.absent,
    rollCount: rollCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'subject': subject,
    'topicId': topicId,
    'topic': {'en': topic.en, 'kn': ?topic.kn},
    'chapter': {'en': chapter.en, 'kn': ?chapter.kn},
    'seen': stepsSeen,
    'total': stepsTotal,
    'minutes': minutes,
    'teacher': ?teacherId,
    'teacherName': teacherName,
    'homework': homework,
    'absent': absent,
    'rolls': rollCount,
  };

  factory ClassRecord.fromJson(Map<String, dynamic> j) => ClassRecord(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    subject: j['subject'] as String? ?? '',
    topicId: j['topicId'] as String? ?? '',
    topic: L10n.of(j['topic']),
    chapter: L10n.of(j['chapter']),
    stepsSeen: (j['seen'] as num?)?.toInt() ?? 0,
    stepsTotal: (j['total'] as num?)?.toInt() ?? 0,
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
    teacherId: j['teacher'] as String?,
    teacherName: j['teacherName'] as String? ?? '',
    homework: j['homework'] as String? ?? '',
    absent: [for (final r in (j['absent'] as List?) ?? const []) (r as num).toInt()],
    rollCount: (j['rolls'] as num?)?.toInt() ?? 0,
  );
}

/// One class-quiz question, marked by roll number.
class QuizResult {
  QuizResult({required this.id, required this.at, required this.questionId, required this.topicId, required this.chapterId, required this.right, required this.wrong});
  final String id, questionId, topicId, chapterId;
  final DateTime at;
  final List<int> right, wrong;
  int get asked => right.length + wrong.length;

  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String(), 'q': questionId, 't': topicId, 'c': chapterId, 'right': right, 'wrong': wrong};
  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    questionId: j['q'] as String? ?? '',
    topicId: j['t'] as String? ?? '',
    chapterId: j['c'] as String? ?? '',
    right: [for (final r in (j['right'] as List?) ?? const []) (r as num).toInt()],
    wrong: [for (final r in (j['wrong'] as List?) ?? const []) (r as num).toInt()],
  );
}

/// A mock test's scores by roll number (A = absent is left out).
class TestResult {
  TestResult({required this.id, required this.at, required this.pattern, required this.maxMarks, required this.scores});
  final String id, pattern;
  final DateTime at;
  final num maxMarks;
  final Map<int, num> scores;

  double get average => scores.isEmpty ? 0 : scores.values.fold<num>(0, (a, b) => a + b) / scores.length;

  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String(), 'pattern': pattern, 'max': maxMarks, 'scores': {for (final e in scores.entries) '${e.key}': e.value}};
  factory TestResult.fromJson(Map<String, dynamic> j) => TestResult(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    pattern: j['pattern'] as String? ?? '',
    maxMarks: j['max'] as num? ?? 0,
    scores: {for (final e in ((j['scores'] as Map?) ?? const {}).entries) int.parse('${e.key}'): e.value as num},
  );
}

/// A house: a range of roll numbers and its XP.
class House {
  const House({required this.name, required this.from, required this.to, this.xp = 0});
  final L10n name;
  final int from, to, xp;
  bool has(int roll) => roll >= from && roll <= to;
  List<int> get rolls => [for (var r = from; r <= to; r++) r];

  static const names = [L10n('Kaveri', 'ಕಾವೇರಿ'), L10n('Tunga', 'ತುಂಗಾ'), L10n('Sharavathi', 'ಶರಾವತಿ'), L10n('Krishna', 'ಕೃಷ್ಣಾ')];

  /// Four houses splitting the roll numbers evenly.
  static List<House> defaults(int rollCount) {
    final per = (rollCount / 4).ceil();
    return [for (var i = 0; i < 4; i++) House(name: names[i], from: i * per + 1, to: ((i + 1) * per).clamp(1, rollCount))];
  }

  House copyWith({int? xp, int? from, int? to}) => House(name: name, from: from ?? this.from, to: to ?? this.to, xp: xp ?? this.xp);
  Map<String, dynamic> toJson() => {'name': {'en': name.en, 'kn': ?name.kn}, 'from': from, 'to': to, 'xp': xp};
  factory House.fromJson(Map<String, dynamic> j) => House(name: L10n.of(j['name']), from: (j['from'] as num).toInt(), to: (j['to'] as num).toInt(), xp: (j['xp'] as num?)?.toInt() ?? 0);
}
