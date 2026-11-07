import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/licence.dart';
import '../../engine/model.dart';
import '../combined/kit.dart' show ArtView, Art;
import 'help.dart';
import 'kit.dart';
import 'lesson.dart';
import 'now.dart';
import 'practice.dart';
import 'quiz.dart';
import 'school.dart';
import 'shell.dart';
import 'tour.dart';

const _pad = 140.0;

/// The art on the class card, by subject.
Art artFor(String subject) => switch (subject) {
  'physics' => Art.earth,
  'chemistry' => Art.molecule,
  'biology' => Art.flask,
  'maths' || 'statistics' => Art.graph,
  'computer_science' || 'electronics' => Art.circuit,
  _ => Art.orbit,
};

/// Opens the class: the lesson where it was left, in simple class mode.
Future<void> startClass(BuildContext context, ClassNow c) async {
  if (!c.hasLesson) {
    final l = ServicesScope.of(context).config.lang;
    toast(context, tr(l, 'No lesson installed for this subject yet. Pick one from Teach a lesson.', 'ಈ ವಿಷಯಕ್ಕೆ ಇನ್ನೂ ಪಾಠ ಇಲ್ಲ. “ಪಾಠ ಮಾಡಿ” ಯಿಂದ ಆರಿಸಿ.'));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SimpleLessonScreen(pack: c.pack!, lesson: c.lesson!, period: c.period)));
}

/// 03 · Home. Simple by default: your class now and one big button, four big cards below.
/// "Show all tools" turns it into the confident teacher's page (11). The voice guide runs over
/// it the first time (04).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.tour});

  /// Force the guide on (true) or off (false); by default it runs until it has been finished.
  final bool? tour;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _start = GlobalKey(), _cards = GlobalKey(), _switch = GlobalKey(), _help = GlobalKey();
  bool _tour = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tour = widget.tour ?? !ServicesScope.of(context).school.tourDone;
  }

  Services get s => ServicesScope.of(context);

  HelpInfo _helpInfo(ClassNow c) {
    final school = s.school;
    if (school.history.where((r) => r.teacherId == school.current?.id).isEmpty && c.hasLesson) {
      return HelpInfo(
        next: const L10n('Tap “Start my class”. The lesson opens on the first step.', '“ನನ್ನ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ” ಒತ್ತಿ. ಪಾಠ ಮೊದಲ ಹಂತದಲ್ಲಿ ತೆರೆಯುತ್ತದೆ.'),
        detail: const L10n('Want to try first? Turn on Show all tools and open Practice class. Nothing is saved there.', 'ಮೊದಲು ಪ್ರಯತ್ನಿಸಬೇಕೆ? “ಎಲ್ಲಾ ಸಾಧನಗಳು” ಆನ್ ಮಾಡಿ, ಅಭ್ಯಾಸ ತರಗತಿ ತೆರೆಯಿರಿ.'),
        target: _start,
      );
    }
    if (c.hasLesson) {
      return HelpInfo(
        next: c.lastStep > 0
            ? L10n('Tap “Start my class”. It opens at step ${c.lastStep + 1}, where you left off.', '“ನನ್ನ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ” ಒತ್ತಿ. ನೀವು ನಿಲ್ಲಿಸಿದ ಹಂತ ${c.lastStep + 1} ರಲ್ಲಿ ತೆರೆಯುತ್ತದೆ.')
            : const L10n('Tap “Start my class” to open today’s lesson.', 'ಇಂದಿನ ಪಾಠ ತೆರೆಯಲು “ನನ್ನ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ” ಒತ್ತಿ.'),
        target: _start,
      );
    }
    return HelpInfo(next: const L10n('Tap “Teach a lesson” and pick a chapter.', '“ಪಾಠ ಮಾಡಿ” ಒತ್ತಿ, ಅಧ್ಯಾಯ ಆರಿಸಿ.'), target: _cards);
  }

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final c = classNow(s);
      final phone = usePhoneLayout(context);
      final showAll = school.showAll && !phone;
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          Positioned.fill(child: phone ? _phone(l, c, school) : DesignCanvas(child: showAll ? _all(l, c, school) : _board(l, c, school))),
          const Positioned(top: 8, left: 0, right: 0, child: Center(child: LicenceBanner())),
          if (_tour)
            Positioned.fill(
              child: GuideTour(
                steps: guideSteps(start: _start, cards: _cards, toggle: _switch, help: _help),
                onDone: () {
                  school.setTourDone(true);
                  setState(() => _tour = false);
                },
              ),
            ),
        ]),
      );
    },
  );

  void _toggleLang() {
    final cfg = s.config;
    if (cfg.kannadaOffered) cfg.setLang(cfg.lang == Lang.en ? Lang.kn : Lang.en);
  }

  Future<void> _teacherMenu() async {
    final l = s.config.lang, t = s.school.current;
    await showZxDialog<void>(
      context,
      width: 1100,
      title: t?.name ?? '',
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ZxButton(tr(l, 'Switch teacher', 'ಶಿಕ್ಷಕರನ್ನು ಬದಲಿಸಿ'), key: const ValueKey('signOut'), icon: Icons.swap_horiz_rounded, bg: S.ink, height: 140, size: 40, onTap: () {
          Navigator.pop(ctx);
          s.school.signIn(null);
        }),
        const SizedBox(height: 24),
        ZxButton(tr(l, 'Play the guide again', 'ಮಾರ್ಗದರ್ಶಿ ಮತ್ತೆ ಕೇಳಿ'), key: const ValueKey('replayGuide'), icon: Icons.record_voice_over_rounded, bg: S.mist, fg: S.ink, height: 140, size: 40, onTap: () {
          Navigator.pop(ctx);
          setState(() => _tour = true);
        }),
        const SizedBox(height: 24),
        ZxButton(tr(l, 'Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'), icon: Icons.school_rounded, bg: S.mist, fg: S.ink, height: 140, size: 40, onTap: () {
          Navigator.pop(ctx);
          openPractice(context);
        }),
      ]),
    );
  }

  Widget _top(Lang l, SchoolStore school, {bool phone = false}) {
    final t = school.current;
    final now = s.clock();
    return Row(children: [
      if (phone) Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Brand(size: 60))) else const Brand(size: 72),
      if (!phone) ...[
        const SizedBox(width: 40),
        Expanded(child: Text('${s.config.collegeName} · ${shortDate(l, now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(32, c: S.muted))),
        offlineTag(l),
        const SizedBox(width: 20),
        if (s.config.kannadaOffered) ...[
          Press(key: const ValueKey('homeLang'), onTap: _toggleLang, child: Tag(l == Lang.kn ? 'English' : 'ಕನ್ನಡ', icon: Icons.translate_rounded, bg: S.mist, size: 30)),
          const SizedBox(width: 20),
        ],
      ] else ...[
        const SizedBox(width: 16),
        if (s.config.kannadaOffered) ...[
          Press(key: const ValueKey('homeLang'), onTap: _toggleLang, child: Tag(l == Lang.kn ? 'EN' : 'ಕ', icon: Icons.translate_rounded, bg: S.mist, size: 26)),
          const SizedBox(width: 16),
        ],
      ],
      if (t != null)
        Press(
          key: const ValueKey('teacherPill'),
          onTap: _teacherMenu,
          child: Container(
            padding: EdgeInsets.fromLTRB(10, 10, phone ? 10 : 34, 10),
            decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              teacherFace(t, size: phone ? 64 : 80),
              if (!phone) ...[const SizedBox(width: 18), Text(t.firstName, style: tx(34, c: S.ink, w: FontWeight.w600))],
            ]),
          ),
        ),
    ]);
  }

  Widget _hello(Lang l, double size, {bool all = false}) {
    final name = s.school.current?.firstName ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${greeting(l, s.clock())}${name.isEmpty ? '' : ', $name'}', style: tx(size * .36, c: S.eyebrow, w: FontWeight.w600)),
      SizedBox(height: size * .08),
      Text(all ? tr(l, 'What do you need today?', 'ಇಂದು ನಿಮಗೆ ಏನು ಬೇಕು?') : tr(l, 'What are you teaching today?', 'ಇಂದು ಏನು ಕಲಿಸುತ್ತಿದ್ದೀರಿ?'), maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(size, l: l)),
    ]);
  }

  Widget _startButton(Lang l, ClassNow c, {double h = 200, double size = 64}) => KeyedSubtree(
    key: _start,
    child: ZxButton(tr(l, 'Start my class', 'ನನ್ನ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ'), key: const ValueKey('startClass'), icon: Icons.play_arrow_rounded, height: h, size: size, shadow: true, onTap: () => startClass(context, c)),
  );

  String _when(Lang l, ClassNow c) {
    final p = c.period;
    if (p == null) return tr(l, 'Your next lesson', 'ನಿಮ್ಮ ಮುಂದಿನ ಪಾಠ');
    final t = '${Period.clock(p.start)} – ${Period.clock(p.end)}';
    return c.isNow ? tr(l, 'Your class now · $t', 'ಈಗ ನಿಮ್ಮ ತರಗತಿ · $t') : tr(l, 'Your next class · $t', 'ನಿಮ್ಮ ಮುಂದಿನ ತರಗತಿ · $t');
  }

  Widget _nowTag(Lang l, ClassNow c, double size) => Tag(_when(l, c), icon: c.isNow ? Icons.circle : Icons.schedule_rounded, fg: c.isNow ? S.green : S.ink, bg: Colors.white, size: size);

  String _what(Lang l, ClassNow c) => c.hasLesson ? '${c.chapter!.title.t(l)} · ${c.lesson!.title.t(l)}' : tr(l, 'No lesson installed yet for ${subjectName(c.subject, Lang.en)}', '${subjectName(c.subject, l)}ಗೆ ಇನ್ನೂ ಪಾಠ ಇಲ್ಲ');

  List<Widget> _chips(Lang l, ClassNow c, double size) => [
    if (c.topicNo > 0) Tag(tr(l, 'Topic ${c.topicNo} of ${c.topicCount}', 'ವಿಷಯ ${c.topicNo} / ${c.topicCount}'), size: size),
    if (c.minutesLeft != null) Tag(tr(l, '${c.minutesLeft} minutes left', 'ಇನ್ನೂ ${c.minutesLeft} ನಿಮಿಷ'), icon: Icons.schedule_rounded, size: size),
    if (c.lastStep > 0) Tag(tr(l, 'Last time: up to step ${c.lastStep + 1}', 'ಕಳೆದ ಬಾರಿ: ಹಂತ ${c.lastStep + 1} ರವರೆಗೆ'), icon: Icons.history_rounded, size: size),
  ];

  List<(Key, Color, IconData, String, String, VoidCallback)> _four(Lang l, ClassNow c) => [
    (const ValueKey('cardTeach'), S.lavender, Icons.slideshow_rounded, tr(l, 'Teach a lesson', 'ಪಾಠ ಮಾಡಿ'), tr(l, 'Any chapter, step by step', 'ಯಾವುದೇ ಅಧ್ಯಾಯ, ಹಂತ ಹಂತವಾಗಿ'), () => openSection(context, Section.teach, standalone: true)),
    (const ValueKey('cardBoard'), S.peach, Icons.edit_rounded, tr(l, 'Write on the board', 'ಬೋರ್ಡ್‌ನಲ್ಲಿ ಬರೆಯಿರಿ'), tr(l, 'A clean board and a pen', 'ಖಾಲಿ ಬೋರ್ಡ್ ಮತ್ತು ಪೆನ್'), () => openBoard(context)),
    (const ValueKey('cardQuiz'), S.mint, Icons.quiz_rounded, tr(l, 'Quiz the class', 'ತರಗತಿಗೆ ಪ್ರಶ್ನೆ ಕೇಳಿ'), tr(l, 'Ask, then tap who is right', 'ಕೇಳಿ, ಸರಿ ಉತ್ತರಕ್ಕೆ ಒತ್ತಿ'), () => openSimpleQuiz(context, c)),
    (const ValueKey('cardLibrary'), S.butter, Icons.view_in_ar_rounded, tr(l, 'Find a 3D model or lab', '3D ಮಾದರಿ, ಲ್ಯಾಬ್'), tr(l, 'Solar system, pendulum…', 'ಸೌರವ್ಯೂಹ, ಲೋಲಕ…'), () => openSection(context, Section.library, standalone: true)),
  ];

  Widget _bottom(Lang l, SchoolStore school, ClassNow c, {required bool on, bool phone = false}) => Row(children: [
    KeyedSubtree(key: _switch, child: ZxSwitch(key: const ValueKey('showAll'), on: on, w: phone ? 100 : 132, onChanged: school.setShowAll)),
    SizedBox(width: phone ? 18 : 28),
    Expanded(
      child: GestureDetector(
        onTap: () => school.setShowAll(!on),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(l, 'Show all tools', 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ'), style: tx(phone ? 26 : 38, c: S.ink, w: FontWeight.w700, h: 1.15)),
          if (!phone) Text(on ? tr(l, 'On · everything is on this page', 'ಆನ್ · ಎಲ್ಲವೂ ಈ ಪುಟದಲ್ಲಿದೆ') : tr(l, 'For confident teachers. You can switch back any time.', 'ಅನುಭವಿ ಶಿಕ್ಷಕರಿಗೆ. ಯಾವಾಗ ಬೇಕಾದರೂ ಹಿಂತಿರುಗಿಸಬಹುದು.'), style: tx(30, c: S.muted, h: 1.3)),
        ]),
      ),
    ),
    SizedBox(width: phone ? 16 : 40),
    KeyedSubtree(key: _help, child: phone ? HelpChip(info: () => _helpInfo(c)) : HelpFab(info: () => _helpInfo(c), size: 40)),
  ]);

  Widget _board(Lang l, ClassNow c, SchoolStore school) => Padding(
    padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 44),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _top(l, school),
      const SizedBox(height: 44),
      _hello(l, 112),
      const SizedBox(height: 40),
      SizedBox(
        height: 500,
        child: Container(
          padding: const EdgeInsets.fromLTRB(72, 40, 72, 40),
          decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(64)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                _nowTag(l, c, 32),
                const SizedBox(height: 24),
                Text(classLine(s, c.subject, l, period: c.period), maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(104, l: l)),
                const SizedBox(height: 14),
                Text(_what(l, c), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(46, c: S.cardText)),
                const SizedBox(height: 24),
                Flexible(child: ClipRect(child: Wrap(spacing: 14, runSpacing: 14, children: _chips(l, c, 30)))),
              ]),
            ),
            ArtView(artFor(c.subject), color: S.ink, size: 300, opacity: .55),
            const SizedBox(width: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                _startButton(l, c),
                const SizedBox(height: 22),
                Text(c.lastStep > 0 ? tr(l, 'Opens the lesson where you left off', 'ನೀವು ನಿಲ್ಲಿಸಿದಲ್ಲಿಂದ ಪಾಠ ತೆರೆಯುತ್ತದೆ') : tr(l, 'Opens the lesson on its first step', 'ಪಾಠ ಮೊದಲ ಹಂತದಲ್ಲಿ ತೆರೆಯುತ್ತದೆ'), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: tx(32, c: S.cardText)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 40),
      Expanded(
        key: _cards,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (k, bg, ic, t, sub, go)) in _four(l, c).indexed) ...[
            if (i > 0) const SizedBox(width: 40),
            Expanded(child: Press(key: k, radius: 56, onTap: go, child: ZxCard(bg: bg, icon: ic, title: t, sub: sub, lang: l, titleSize: 60, iconSize: 104, subLines: 1, pad: 44))),
          ],
        ]),
      ),
      const SizedBox(height: 36),
      _bottom(l, school, c, on: false),
    ]),
  );

  Widget _all(Lang l, ClassNow c, SchoolStore school) {
    final me = school.current?.id;
    final today = [for (final p in school.today(s.clock())) if (me == null || p.teacherId == null || p.teacherId!.isEmpty || p.teacherId == me) p];
    final mins = s.clock().hour * 60 + s.clock().minute;
    final next = today.where((p) => p.startMin > mins).firstOrNull;
    final cards = [
      (Section.today, S.sky, Icons.today_rounded, tr(l, 'Today', 'ಇಂದು'), tr(l, 'Your timetable and what comes next', 'ನಿಮ್ಮ ವೇಳಾಪಟ್ಟಿ ಮತ್ತು ಮುಂದೇನು'), [tr(l, '${today.length} classes', '${today.length} ತರಗತಿಗಳು'), if (next != null) tr(l, 'Next at ${Period.clock(next.start)}', '${Period.clock(next.start)}ಕ್ಕೆ ಮುಂದಿನದು')]),
      (Section.teach, S.lavender, Icons.slideshow_rounded, tr(l, 'Teach', 'ಪಾಠ'), tr(l, 'Every chapter, step by step, with voice', 'ಪ್ರತಿ ಅಧ್ಯಾಯ, ಹಂತ ಹಂತವಾಗಿ, ಧ್ವನಿಯೊಂದಿಗೆ'), [tr(l, 'Lessons', 'ಪಾಠಗಳು'), tr(l, 'Exam practice', 'ಪರೀಕ್ಷಾ ಅಭ್ಯಾಸ'), tr(l, 'Self-learning', 'ಸ್ವಯಂ ಕಲಿಕೆ')]),
      (Section.board, S.peach, Icons.draw_rounded, tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'), tr(l, 'Write, draw shapes, add a 3D model', 'ಬರೆಯಿರಿ, ಆಕಾರ ಬಿಡಿಸಿ, 3D ಮಾದರಿ ಸೇರಿಸಿ'), [tr(l, 'Pen', 'ಪೆನ್'), tr(l, 'Shapes', 'ಆಕಾರಗಳು'), tr(l, 'Pages', 'ಪುಟಗಳು')]),
      (Section.tools, S.mint, Icons.groups_rounded, tr(l, 'Class tools', 'ತರಗತಿ ಸಾಧನಗಳು'), tr(l, 'Quiz, mock tests, teams and worksheets', 'ಪ್ರಶ್ನೋತ್ತರ, ಅಣಕು ಪರೀಕ್ಷೆ, ತಂಡಗಳು, ವರ್ಕ್‌ಶೀಟ್'), [tr(l, 'Quiz', 'ಪ್ರಶ್ನೆ'), tr(l, 'Mock test', 'ಅಣಕು'), tr(l, 'Teams', 'ತಂಡ'), tr(l, 'Plan', 'ಯೋಜನೆ')]),
      (Section.library, S.butter, Icons.view_in_ar_rounded, tr(l, 'Library', 'ಗ್ರಂಥಾಲಯ'), tr(l, '3D models, virtual labs and simulations', '3D ಮಾದರಿಗಳು, ವರ್ಚುವಲ್ ಲ್ಯಾಬ್, ಸಿಮ್ಯುಲೇಶನ್'), [tr(l, '3D models', '3D ಮಾದರಿ'), tr(l, 'Labs', 'ಲ್ಯಾಬ್'), tr(l, 'Simulations', 'ಸಿಮ್ಯುಲೇಶನ್')]),
      (Section.reports, S.pink, Icons.insights_rounded, tr(l, 'Reports', 'ವರದಿಗಳು'), tr(l, 'How far each class has got, quiz results', 'ಪ್ರತಿ ತರಗತಿ ಎಷ್ಟು ಮುಂದೆ ಬಂದಿದೆ, ಫಲಿತಾಂಶ'), [tr(l, 'Syllabus covered', 'ಪಠ್ಯ ಮುಗಿದದ್ದು'), tr(l, 'Quiz results', 'ಪ್ರಶ್ನೆ ಫಲಿತಾಂಶ')]),
      (Section.settings, S.mist, Icons.settings_rounded, tr(l, 'Settings', 'ಸೆಟ್ಟಿಂಗ್ಸ್'), tr(l, 'Language, board size, voice, school PIN', 'ಭಾಷೆ, ಬೋರ್ಡ್ ಗಾತ್ರ, ಧ್ವನಿ, ಶಾಲೆ PIN'), [tr(l, 'Language', 'ಭಾಷೆ'), tr(l, 'Text size', 'ಅಕ್ಷರ ಗಾತ್ರ'), 'PIN']),
      (null, S.greenSoft, Icons.school_rounded, tr(l, 'Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'), tr(l, 'A 3-minute pretend class. Nothing is saved.', '3 ನಿಮಿಷದ ಅಭ್ಯಾಸ ತರಗತಿ. ಏನೂ ಉಳಿಯುವುದಿಲ್ಲ.'), [tr(l, '3 minutes', '3 ನಿಮಿಷ'), tr(l, 'Safe to try', 'ಸುರಕ್ಷಿತ')]),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 60, _pad, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top(l, school),
        const SizedBox(height: 48),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _hello(l, 112, all: true)),
          const SizedBox(width: 40),
          Container(
            padding: const EdgeInsets.fromLTRB(48, 24, 24, 24),
            decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.period == null ? tr(l, 'Your next lesson', 'ನಿಮ್ಮ ಮುಂದಿನ ಪಾಠ') : (c.isNow ? tr(l, 'Your class now · ${Period.clock(c.period!.start)}', 'ಈಗ ನಿಮ್ಮ ತರಗತಿ · ${Period.clock(c.period!.start)}') : tr(l, 'Next class · ${Period.clock(c.period!.start)}', 'ಮುಂದಿನ ತರಗತಿ · ${Period.clock(c.period!.start)}')), style: tx(28, c: S.green, w: FontWeight.w600)),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text('${classLine(s, c.subject, l, period: c.period)}${c.hasLesson ? ' · ${c.chapter!.title.t(l)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(38, c: S.ink, w: FontWeight.w700, h: 1.2)),
                ),
              ]),
              const SizedBox(width: 36),
              _startButton(l, c, h: 130, size: 42),
            ]),
          ),
        ]),
        const SizedBox(height: 48),
        Expanded(
          key: _cards,
          child: LayoutBuilder(builder: (context, box) {
            const gap = 36.0;
            final w = (box.maxWidth - gap * 3) / 4, h = (box.maxHeight - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (sec, bg, ic, t, sub, tags) in cards)
                SizedBox(
                  width: w, height: h,
                  child: Press(
                    key: ValueKey('all-${sec?.name ?? 'practice'}'),
                    radius: 40,
                    onTap: () => sec == null ? openPractice(context) : openSection(context, sec),
                    child: ZxCard(bg: bg, icon: ic, title: t, sub: sub, tags: tags, lang: l, titleSize: 58, compact: true),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 40),
        _bottom(l, school, c, on: true),
      ]),
    );
  }

  Widget _phone(Lang l, ClassNow c, SchoolStore school) {
    final tiles = school.showAll
        ? [
            for (final sec in Section.values)
              (ValueKey('all-${sec.name}'), [S.sky, S.lavender, S.peach, S.mint, S.butter, S.pink, S.mist][sec.index], sectionLabel(sec).$1, sectionLabel(sec).$2.t(l), '', () => openSection(context, sec)),
            (const ValueKey('all-practice'), S.greenSoft, Icons.school_rounded, tr(l, 'Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'), '', () => openPractice(context)),
          ]
        : _four(l, c);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(40, 36, 40, 36), children: [
        _top(l, school, phone: true),
        const SizedBox(height: 44),
        _hello(l, 78),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
          decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(48)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _nowTag(l, c, 24),
            const SizedBox(height: 24),
            Text(classLine(s, c.subject, l, period: c.period), maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(60, l: l)),
            const SizedBox(height: 10),
            Text(_what(l, c), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(30, c: S.cardText)),
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: _chips(l, c, 24).take(2).toList()),
            const SizedBox(height: 36),
            SizedBox(width: double.infinity, child: _startButton(l, c, h: 136, size: 42)),
          ]),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          key: _cards,
          builder: (context, box) {
            const gap = 24.0;
            final w = (box.maxWidth - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (k, bg, ic, t, _, go) in tiles)
                SizedBox(
                  width: w, height: 300,
                  child: Press(
                    key: k,
                    radius: 40,
                    onTap: go,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 84, height: 84,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                            child: Icon(ic, size: 48, color: S.ink),
                          ),
                          const Spacer(),
                          const ArrowChip(size: 56),
                        ]),
                        const Spacer(),
                        Flexible(child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(40, l: l))),
                      ]),
                    ),
                  ),
                ),
            ]);
          },
        ),
        const SizedBox(height: 28),
        _bottom(l, school, c, on: school.showAll, phone: true),
      ]),
    );
  }
}

/// A warning pill when the licence has lapsed (lessons keep working).
class LicenceBanner extends StatelessWidget {
  const LicenceBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return FutureBuilder<LicenceStatus>(
      future: s.licence(),
      builder: (context, snap) {
        final st = snap.data, l = s.config.lang;
        final String? msg = switch (st?.state) {
          LicenceState.grace => tr(l, 'Licence expired. ${st!.daysLeft} days left to renew; lessons keep working.', 'ಪರವಾನಗಿ ಮುಗಿದಿದೆ. ನವೀಕರಿಸಲು ${st.daysLeft} ದಿನ; ಪಾಠಗಳು ನಡೆಯುತ್ತವೆ.'),
          LicenceState.lapsed => tr(l, 'Licence expired. Lessons keep working, but new content is paused until the college renews.', 'ಪರವಾನಗಿ ಮುಗಿದಿದೆ. ಪಾಠಗಳು ನಡೆಯುತ್ತವೆ, ಹೊಸ ವಿಷಯ ನಿಂತಿದೆ.'),
          LicenceState.invalid => tr(l, 'This board’s licence could not be verified. Please contact Zynetix support.', 'ಈ ಬೋರ್ಡ್‌ನ ಪರವಾನಗಿ ಪರಿಶೀಲನೆ ಆಗಲಿಲ್ಲ. ಬೆಂಬಲವನ್ನು ಸಂಪರ್ಕಿಸಿ.'),
          _ => null,
        };
        if (msg == null) return const SizedBox.shrink();
        return Container(
          key: const ValueKey('licenceBanner'),
          constraints: const BoxConstraints(maxWidth: 2200),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          decoration: BoxDecoration(color: S.peach, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 44, color: S.rust),
            const SizedBox(width: 16),
            Flexible(child: Text(msg, style: tx(28, c: S.rust, w: FontWeight.w600))),
          ]),
        );
      },
    );
  }
}
