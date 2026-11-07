import 'package:flutter/material.dart';

import '../../core/kiosk.dart';
import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import '../pin.dart';
import '../settings.dart' show openSettings;
import 'help.dart';
import 'kit.dart';
import 'school.dart';
import 'shell.dart';
import 'start.dart' show addTeacherDialog;

/// Settings: language, board size and voice for everyone; the school's teachers, timetable,
/// PINs, help contact and exam date behind the school PIN.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool admin = false;

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final cfg = s.config;
      final phone = usePhoneLayout(context);

      Widget panel(String title, List<Widget> children, {String? sub}) => Container(
        margin: const EdgeInsets.only(bottom: 36),
        padding: EdgeInsets.all(phone ? 36 : 52),
        decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(48)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: hd(56, l: l)),
          if (sub != null) Text(sub, style: tx(30, c: S.muted)),
          const SizedBox(height: 28),
          ...children,
        ]),
      );
      Widget seg<T>(T value, List<(T, String)> items, ValueChanged<T> on, String keyBase) => Wrap(spacing: 14, runSpacing: 14, children: [
        for (final (v, t) in items)
          Press(key: ValueKey('$keyBase-$v'), onTap: () => on(v), child: Tag(t, bg: v == value ? S.ink : Colors.white, fg: v == value ? Colors.white : S.ink, size: 32)),
      ]);

      final everyone = [
        panel(tr(l, 'Language', 'ಭಾಷೆ'), [
          seg<Lang>(l, [(Lang.en, 'English'), if (cfg.kannadaOffered) (Lang.kn, 'ಕನ್ನಡ')], cfg.setLang, 'set-lang'),
        ]),
        panel(tr(l, 'Board size', 'ಬೋರ್ಡ್ ಗಾತ್ರ'), [
          seg<String>(cfg.displaySize, [('normal', tr(l, 'Normal', 'ಸಾಮಾನ್ಯ')), ('large', tr(l, 'Large', 'ದೊಡ್ಡದು')), ('classroom', tr(l, 'Classroom board', 'ತರಗತಿ ಬೋರ್ಡ್'))], cfg.setDisplaySize, 'set-size'),
        ], sub: tr(l, 'Classroom board makes everything big enough for the back bench.', 'ತರಗತಿ ಬೋರ್ಡ್ ಎಲ್ಲವನ್ನೂ ಹಿಂದಿನ ಬೆಂಚಿಗೂ ಕಾಣುವಷ್ಟು ದೊಡ್ಡದಾಗಿಸುತ್ತದೆ.')),
        panel(tr(l, 'Lesson voice', 'ಪಾಠದ ಧ್ವನಿ'), [
          seg<String>(cfg.playMode, [('auto', tr(l, 'Plays like a video', 'ವೀಡಿಯೊದಂತೆ')), ('manual', tr(l, 'I tap Next', 'ನಾನು “ಮುಂದೆ” ಒತ್ತುತ್ತೇನೆ'))], cfg.setPlayMode, 'set-play'),
          const SizedBox(height: 20),
          Row(children: [
            Flexible(child: Text(tr(l, 'Voice guide on Home', 'ಮುಖಪುಟದ ಧ್ವನಿ ಮಾರ್ಗದರ್ಶಿ'), style: tx(32, c: S.ink, w: FontWeight.w600))),
            const SizedBox(width: 24),
            ZxSwitch(key: const ValueKey('set-guide'), on: !school.guideMuted, w: 110, onChanged: (v) => school.setGuideMuted(!v)),
          ]),
          const SizedBox(height: 12),
          Text(tr(l, 'Chapter voices download from Teach → a chapter (needs internet once).', 'ಅಧ್ಯಾಯದ ಧ್ವನಿಗಳನ್ನು ಪಾಠ → ಅಧ್ಯಾಯದಿಂದ ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ (ಒಮ್ಮೆ ಇಂಟರ್ನೆಟ್ ಬೇಕು).'), style: tx(28, c: S.muted)),
        ]),
        panel(tr(l, 'School admin', 'ಶಾಲೆಯ ನಿರ್ವಹಣೆ'), [
          if (!admin)
            ZxButton(tr(l, 'Open with the school PIN', 'ಶಾಲೆಯ PIN ನಿಂದ ತೆರೆಯಿರಿ'), key: const ValueKey('openAdmin'), icon: Icons.lock_open_rounded, bg: S.ink, height: 120, size: 34, onTap: () async {
              if (await askPin(context, cfg)) setState(() => admin = true);
            })
          else
            Text(tr(l, 'Open. Teachers, timetable and PINs are below.', 'ತೆರೆದಿದೆ. ಶಿಕ್ಷಕರು, ವೇಳಾಪಟ್ಟಿ ಮತ್ತು PIN ಕೆಳಗಿವೆ.'), style: tx(30, c: S.green, w: FontWeight.w600)),
        ], sub: tr(l, 'Teachers, timetable, PINs, help contact, exam date, kiosk and sync.', 'ಶಿಕ್ಷಕರು, ವೇಳಾಪಟ್ಟಿ, PIN, ಸಹಾಯ ಸಂಪರ್ಕ, ಪರೀಕ್ಷೆ ದಿನಾಂಕ, ಕಿಯೋಸ್ಕ್, ಸಿಂಕ್.')),
      ];

      final adminPanels = !admin
          ? const <Widget>[]
          : [
              panel(tr(l, 'Teachers', 'ಶಿಕ್ಷಕರು'), [
                for (final t in school.teachers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(children: [
                      teacherFace(t, size: 88),
                      const SizedBox(width: 24),
                      Expanded(child: Text('${t.name} · ${t.initials}${t.pinHash != null ? ' · PIN' : ''}', style: tx(34, c: S.ink, w: FontWeight.w600))),
                      ZxButton(tr(l, 'Edit', 'ಬದಲಿಸಿ'), key: ValueKey('editTeacher-${t.id}'), icon: Icons.edit_rounded, bg: Colors.white, fg: S.ink, height: 96, size: 28, onTap: () => _editTeacher(context, t)),
                      const SizedBox(width: 12),
                      ZxButton(tr(l, 'Remove', 'ತೆಗೆಯಿರಿ'), key: ValueKey('removeTeacher-${t.id}'), icon: Icons.delete_outline_rounded, bg: Colors.white, fg: S.rust, height: 96, size: 28, onTap: () => school.removeTeacher(t.id)),
                    ]),
                  ),
                ZxButton(tr(l, 'Add a teacher', 'ಶಿಕ್ಷಕರನ್ನು ಸೇರಿಸಿ'), key: const ValueKey('adminAddTeacher'), icon: Icons.person_add_alt_1_rounded, bg: S.violet, height: 110, size: 32, onTap: () => addTeacherDialog(context, signIn: false)),
                const SizedBox(height: 28),
                Row(children: [
                  ZxSwitch(key: const ValueKey('pinsOn'), on: school.pinsOn, w: 110, onChanged: school.setPinsOn),
                  const SizedBox(width: 24),
                  Expanded(child: Text(tr(l, 'Ask for a PIN on teacher cards (off by default; a teacher without a PIN still opens with a tap)', 'ಶಿಕ್ಷಕರ ಕಾರ್ಡ್‌ಗೆ PIN ಕೇಳಿ (ಡೀಫಾಲ್ಟ್ ಆಫ್)'), style: tx(30, c: S.ink))),
                ]),
              ]),
              panel(tr(l, 'Timetable', 'ವೇಳಾಪಟ್ಟಿ'), [
                if (school.periods.isEmpty) Text(tr(l, 'No periods yet. Add the periods taught on this board.', 'ಇನ್ನೂ ಅವಧಿಗಳಿಲ್ಲ. ಈ ಬೋರ್ಡ್‌ನ ಅವಧಿಗಳನ್ನು ಸೇರಿಸಿ.'), style: tx(30, c: S.muted)),
                for (final p in school.periods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(children: [
                      SizedBox(width: phone ? 200 : 300, child: Text('${Period.clock(p.start)} – ${Period.clock(p.end)}', style: tx(34, c: S.ink, w: FontWeight.w700))),
                      Expanded(
                        child: Text(
                          '${p.label.isEmpty ? '' : '${p.label} · '}${subjectName(p.subject, l)}${school.teacher(p.teacherId) == null ? '' : ' · ${school.teacher(p.teacherId)!.name}'} · ${[for (final d in p.days) (l == Lang.kn ? dayNamesKn : dayNamesEn)[d - 1]].join(' ')}',
                          style: tx(30, c: S.cardText),
                        ),
                      ),
                      ZxButton(tr(l, 'Edit', 'ಬದಲಿಸಿ'), icon: Icons.edit_rounded, bg: Colors.white, fg: S.ink, height: 96, size: 28, onTap: () => _editPeriod(context, p)),
                      const SizedBox(width: 12),
                      ZxButton(tr(l, 'Remove', 'ತೆಗೆಯಿರಿ'), icon: Icons.delete_outline_rounded, bg: Colors.white, fg: S.rust, height: 96, size: 28, onTap: () => school.setPeriods([for (final x in school.periods) if (x.id != p.id) x])),
                    ]),
                  ),
                ZxButton(tr(l, 'Add a period', 'ಅವಧಿ ಸೇರಿಸಿ'), key: const ValueKey('addPeriod'), icon: Icons.add_rounded, bg: S.violet, height: 110, size: 32, onTap: () => _editPeriod(context, null)),
              ]),
              panel(tr(l, 'Help and exam', 'ಸಹಾಯ ಮತ್ತು ಪರೀಕ್ಷೆ'), [
                ZxButton(
                  school.helpContact.isEmpty ? tr(l, 'Set who to call for help', 'ಸಹಾಯಕ್ಕೆ ಯಾರನ್ನು ಕರೆಯಬೇಕು') : school.helpContact,
                  key: const ValueKey('setContact'),
                  icon: Icons.call_rounded,
                  bg: Colors.white,
                  fg: S.ink,
                  height: 110,
                  size: 32,
                  onTap: () => _text(context, tr(l, 'Who to call for help', 'ಸಹಾಯಕ್ಕೆ ಯಾರು'), school.helpContact, school.setHelpContact, hint: tr(l, 'e.g. School office · Mr. Ramesh, ext. 204', 'ಉದಾ: ಶಾಲೆಯ ಕಚೇರಿ · ವಿಸ್ತರಣೆ 204')),
                ),
                const SizedBox(height: 20),
                ZxButton(
                  school.examDate == null ? tr(l, 'Set the exam date', 'ಪರೀಕ್ಷೆ ದಿನಾಂಕ ಹೊಂದಿಸಿ') : tr(l, 'Exam: ${shortDate(l, school.examDate!)} ${school.examDate!.year}', 'ಪರೀಕ್ಷೆ: ${shortDate(l, school.examDate!)} ${school.examDate!.year}'),
                  key: const ValueKey('setExam'),
                  icon: Icons.event_rounded,
                  bg: Colors.white,
                  fg: S.ink,
                  height: 110,
                  size: 32,
                  onTap: () => pickExamDate(context),
                ),
              ]),
              panel(tr(l, 'Board', 'ಬೋರ್ಡ್'), [
                Row(children: [
                  ZxSwitch(on: cfg.kioskOn, w: 110, onChanged: (on) async {
                    await (on ? Kiosk.enter() : Kiosk.exit());
                    await cfg.setKiosk(on);
                  }),
                  const SizedBox(width: 24),
                  Expanded(child: Text(tr(l, 'Kiosk lock: students cannot leave the app', 'ಕಿಯೋಸ್ಕ್ ಲಾಕ್: ವಿದ್ಯಾರ್ಥಿಗಳು ಆಪ್ ಬಿಡಲಾಗದು'), style: tx(30, c: S.ink))),
                ]),
                const SizedBox(height: 20),
                Text(tr(l, '${s.store.packs.length} chapters installed · ${s.outbox.pending().length} logs waiting to sync', '${s.store.packs.length} ಅಧ್ಯಾಯ ಸ್ಥಾಪಿತ · ${s.outbox.pending().length} ಸಿಂಕ್ ಬಾಕಿ'), style: tx(30, c: S.muted)),
                const SizedBox(height: 20),
                ZxButton(tr(l, 'Activate, sync and install packs (needs internet)', 'ಸಕ್ರಿಯಗೊಳಿಸಿ, ಸಿಂಕ್ (ಇಂಟರ್ನೆಟ್ ಬೇಕು)'), key: const ValueKey('openSync'), icon: Icons.sync_rounded, bg: S.peach, fg: S.rust, height: 110, size: 32, onTap: () => openSettings(context, skipPin: true)),
              ]),
            ];

      return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        SectionHeader(
          crumb: '${cfg.collegeName} · ${cfg.sectionLabel}',
          title: tr(l, 'Settings', 'ಸೆಟ್ಟಿಂಗ್ಸ್'),
          help: () => const HelpInfo(next: L10n('Change the language or board size here. The school adds teachers and the timetable under School admin.', 'ಭಾಷೆ ಅಥವಾ ಗಾತ್ರ ಇಲ್ಲಿ ಬದಲಿಸಿ. ಶಾಲೆ ಶಿಕ್ಷಕರು ಮತ್ತು ವೇಳಾಪಟ್ಟಿಯನ್ನು “ಶಾಲೆಯ ನಿರ್ವಹಣೆ” ಯಲ್ಲಿ ಸೇರಿಸುತ್ತದೆ.')),
        ),
        const SizedBox(height: 36),
        ...everyone,
        ...adminPanels,
      ]);
    },
  );

  Future<void> _text(BuildContext context, String title, String value, ValueChanged<String> save, {String? hint}) async {
    final l = ServicesScope.of(context).config.lang;
    final t = TextEditingController(text: value);
    final v = await showZxDialog<String>(
      context,
      title: title,
      body: (ctx) => ZxField(fieldKey: const ValueKey('textField'), controller: t, label: hint ?? title, autofocus: true),
      actions: (ctx) => [
        ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
        ZxButton(tr(l, 'Save', 'ಉಳಿಸಿ'), key: const ValueKey('textSave'), bg: S.violet, onTap: () => Navigator.pop(ctx, t.text)),
      ],
    );
    if (v != null) save(v);
  }

  Future<void> _editTeacher(BuildContext context, Teacher t) async {
    final s = ServicesScope.of(context);
    final l = s.config.lang;
    final name = TextEditingController(text: t.name), ini = TextEditingController(text: t.initials), pin = TextEditingController();
    final ok = await showZxDialog<bool>(
      context,
      title: tr(l, 'Edit teacher', 'ಶಿಕ್ಷಕರನ್ನು ಬದಲಿಸಿ'),
      body: (ctx) => Column(children: [
        ZxField(controller: name, label: tr(l, 'Name', 'ಹೆಸರು')),
        const SizedBox(height: 24),
        ZxField(controller: ini, label: tr(l, 'Initials', 'ಮೊದಲಕ್ಷರ'), maxLength: 3),
        const SizedBox(height: 24),
        ZxField(controller: pin, label: tr(l, 'New PIN (blank: keep; 0: remove)', 'ಹೊಸ PIN (ಖಾಲಿ: ಹಾಗೇ; 0: ತೆಗೆ)'), number: true, obscure: true, maxLength: 6),
      ]),
      actions: (ctx) => [
        ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
        ZxButton(tr(l, 'Save', 'ಉಳಿಸಿ'), bg: S.violet, onTap: () => Navigator.pop(ctx, true)),
      ],
    );
    if (ok != true || name.text.trim().isEmpty) return;
    s.school.updateTeacher(t.copyWith(
      name: name.text.trim(),
      initials: ini.text.trim().isEmpty ? Teacher.initialsOf(name.text) : ini.text.trim().toUpperCase(),
      pinHash: pin.text.isEmpty || pin.text == '0' ? null : Teacher.hash(pin.text),
      clearPin: pin.text == '0',
    ));
  }

  Future<void> _editPeriod(BuildContext context, Period? p) async {
    final s = ServicesScope.of(context);
    final l = s.config.lang;
    final school = s.school;
    final start = TextEditingController(text: p?.start ?? '09:00'), end = TextEditingController(text: p?.end ?? '09:45'), label = TextEditingController(text: p?.label ?? '');
    var subject = p?.subject ?? (s.subjects.isEmpty ? 'physics' : s.subjects.first);
    var teacher = p?.teacherId ?? '';
    final days = {...(p?.days ?? const [1, 2, 3, 4, 5, 6])};
    final ok = await showZxDialog<bool>(
      context,
      width: 1800,
      title: p == null ? tr(l, 'Add a period', 'ಅವಧಿ ಸೇರಿಸಿ') : tr(l, 'Edit the period', 'ಅವಧಿ ಬದಲಿಸಿ'),
      body: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: ZxField(fieldKey: const ValueKey('periodStart'), controller: start, label: tr(l, 'Starts (24-hour, 09:45)', 'ಆರಂಭ (09:45)'))),
            const SizedBox(width: 24),
            Expanded(child: ZxField(fieldKey: const ValueKey('periodEnd'), controller: end, label: tr(l, 'Ends (10:40)', 'ಮುಕ್ತಾಯ (10:40)'))),
            const SizedBox(width: 24),
            Expanded(child: ZxField(controller: label, label: tr(l, 'Class (blank: this board’s)', 'ತರಗತಿ (ಖಾಲಿ: ಈ ಬೋರ್ಡ್)'))),
          ]),
          const SizedBox(height: 28),
          Text(tr(l, 'Subject', 'ವಿಷಯ'), style: tx(30, c: S.muted, w: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final sub in s.subjects) Press(key: ValueKey('periodSubj-$sub'), onTap: () => set(() => subject = sub), child: Tag(subjectName(sub, l), bg: sub == subject ? S.ink : S.mist, fg: sub == subject ? Colors.white : S.ink, size: 30)),
          ]),
          const SizedBox(height: 28),
          Text(tr(l, 'Teacher', 'ಶಿಕ್ಷಕರು'), style: tx(30, c: S.muted, w: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            Press(onTap: () => set(() => teacher = ''), child: Tag(tr(l, 'Anyone', 'ಯಾರಾದರೂ'), bg: teacher.isEmpty ? S.ink : S.mist, fg: teacher.isEmpty ? Colors.white : S.ink, size: 30)),
            for (final t in school.teachers) Press(onTap: () => set(() => teacher = t.id), child: Tag(t.name, bg: teacher == t.id ? S.ink : S.mist, fg: teacher == t.id ? Colors.white : S.ink, size: 30)),
          ]),
          const SizedBox(height: 28),
          Text(tr(l, 'Days', 'ದಿನಗಳು'), style: tx(30, c: S.muted, w: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var d = 1; d <= 7; d++)
              Press(onTap: () => set(() => days.contains(d) ? days.remove(d) : days.add(d)), child: Tag((l == Lang.kn ? dayNamesKn : dayNamesEn)[d - 1], bg: days.contains(d) ? S.violet : S.mist, fg: days.contains(d) ? Colors.white : S.ink, size: 30)),
          ]),
        ]),
      ),
      actions: (ctx) => [
        ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
        ZxButton(tr(l, 'Save', 'ಉಳಿಸಿ'), key: const ValueKey('periodSave'), icon: Icons.check_rounded, bg: S.violet, onTap: () => Navigator.pop(ctx, true)),
      ],
    );
    if (ok != true) return;
    String? norm(String v) {
      final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(v.trim());
      if (m == null) return null;
      final h = int.parse(m[1]!), mm = int.parse(m[2]!);
      if (h > 23 || mm > 59) return null;
      return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }

    final a = norm(start.text), b = norm(end.text);
    if (a == null || b == null || a.compareTo(b) >= 0 || days.isEmpty) {
      if (context.mounted) toast(context, tr(l, 'Times look wrong. Use 24-hour times like 09:45 and 10:40.', 'ಸಮಯ ತಪ್ಪಾಗಿದೆ. 09:45, 10:40 ರಂತೆ ಬರೆಯಿರಿ.'));
      return;
    }
    final np = Period(id: p?.id ?? 'p${s.clock().microsecondsSinceEpoch}', start: a, end: b, subject: subject, days: days.toList()..sort(), teacherId: teacher.isEmpty ? null : teacher, label: label.text.trim());
    school.setPeriods([for (final x in school.periods) if (x.id != np.id) x, np]);
  }
}

/// Asks for the exam date (the class plan works back from it).
Future<void> pickExamDate(BuildContext context) async {
  final s = ServicesScope.of(context);
  final now = s.clock();
  final d = await showDatePicker(context: context, firstDate: now, lastDate: DateTime(now.year + 2), initialDate: () {
    final want = s.school.examDate ?? DateTime(now.month >= 6 ? now.year + 1 : now.year, 3, 1);
    return want.isBefore(now) ? now : want;
  }());
  if (d != null) s.school.setPlan(examDate: d);
}

