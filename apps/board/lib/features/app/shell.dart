import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../engine/model.dart';
import '../smartboard.dart';
import 'help.dart';
import 'kit.dart';
import 'library.dart';
import 'reports.dart';
import 'settings_view.dart';
import 'teach.dart';
import 'today.dart';
import 'tools.dart';

/// The places "Show all tools" reveals, in the rail's order.
enum Section { today, teach, board, tools, library, reports, settings }

(IconData, L10n) sectionLabel(Section s) => switch (s) {
  Section.today => (Icons.today_rounded, const L10n('Today', 'ಇಂದು')),
  Section.teach => (Icons.slideshow_rounded, const L10n('Teach', 'ಪಾಠ')),
  Section.board => (Icons.draw_rounded, const L10n('Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್')),
  Section.tools => (Icons.groups_rounded, const L10n('Class tools', 'ತರಗತಿ ಸಾಧನಗಳು')),
  Section.library => (Icons.view_in_ar_rounded, const L10n('Library', 'ಗ್ರಂಥಾಲಯ')),
  Section.reports => (Icons.insights_rounded, const L10n('Reports', 'ವರದಿಗಳು')),
  Section.settings => (Icons.settings_rounded, const L10n('Settings', 'ಸೆಟ್ಟಿಂಗ್ಸ್')),
};

/// Opens a place: inside the all-tools shell (rail; bottom bar on phones), or on its own with a
/// Back button ([standalone], from the simple Home).
Future<void> openSection(BuildContext context, Section s, {bool standalone = false}) {
  if (s == Section.board) return openBoard(context);
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => standalone ? SectionPage(section: s) : ToolsShell(initial: s)));
}

/// The board, full screen, with "What do I do now?" (whose Undo takes back the last stroke).
Future<void> openBoard(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const BoardPage()));

class BoardPage extends StatelessWidget {
  const BoardPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final board = SmartboardScreen.shared;
    return Stack(children: [
      const Positioned.fill(child: SmartboardScreen()),
      Positioned(
        right: 32,
        bottom: embedded ? 32 : 180,
        child: HelpChip(
          info: () => HelpInfo(
            next: const L10n('Pick a pen colour and write. Tap Insert to add a 3D model or lab.', 'ಪೆನ್ ಬಣ್ಣ ಆರಿಸಿ ಬರೆಯಿರಿ. 3D ಮಾದರಿ ಅಥವಾ ಲ್ಯಾಬ್‌ಗೆ “ಸೇರಿಸಿ” ಒತ್ತಿ.'),
            detail: const L10n('Close the board with the X at the top. Your pages stay until the board is switched off.', 'ಮೇಲಿನ X ಒತ್ತಿ ಬೋರ್ಡ್ ಮುಚ್ಚಿ. ನಿಮ್ಮ ಪುಟಗಳು ಉಳಿಯುತ್ತವೆ.'),
            undo: () => board.canUndo ? LocalUndo(const L10n('Your last stroke on the board', 'ಬೋರ್ಡ್‌ನ ಕೊನೆಯ ಗೆರೆ'), board.undo) : null,
          ),
        ),
      ),
    ]);
  }
}

/// The top of every place: a small line over a big title, then [trailing] and help.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.crumb, required this.title, required this.help, this.trailing = const []});
  final String crumb, title;
  final HelpInfo Function() help;
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    final phone = usePhoneLayout(context);
    final head = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (crumb.isNotEmpty) Text(crumb, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(phone ? 26 : 32, c: S.muted, w: FontWeight.w500)),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(phone ? 64 : 96, l: l)),
        ]),
      ),
      const SizedBox(width: 20),
      HelpChip(info: help),
    ]);
    if (trailing.isEmpty) return head;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      head,
      const SizedBox(height: 20),
      Wrap(spacing: 20, runSpacing: 16, alignment: phone ? WrapAlignment.start : WrapAlignment.end, children: trailing),
    ]);
  }
}

Widget sectionBody(Section s) => switch (s) {
  Section.today => const TodayView(),
  Section.teach => const TeachView(),
  Section.board => const BoardPage(embedded: true),
  Section.tools => const ToolsView(),
  Section.library => const LibraryView(),
  Section.reports => const ReportsView(),
  Section.settings => const SettingsView(),
};

/// A place on its own (from the simple Home): a Back pill over it.
class SectionPage extends StatelessWidget {
  const SectionPage({super.key, required this.section});
  final Section section;
  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    final phone = usePhoneLayout(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(phone ? 32 : 120, phone ? 24 : 40, phone ? 32 : 120, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              ZxButton(tr(l, 'Back to Home', 'ಮುಖಪುಟಕ್ಕೆ'), key: const ValueKey('backHome'), icon: Icons.arrow_back_rounded, bg: S.mist, fg: S.ink, height: phone ? 96 : 112, size: phone ? 28 : 34, onTap: () => Navigator.of(context).maybePop()),
            ]),
            SizedBox(height: phone ? 16 : 24),
            Expanded(child: sectionBody(section)),
          ]),
        ),
      ),
    );
  }
}

/// Every tool: a navy rail on the left (a bottom bar on phones) and the place on the right.
class ToolsShell extends StatefulWidget {
  const ToolsShell({super.key, this.initial = Section.today});
  final Section initial;
  @override
  State<ToolsShell> createState() => _ToolsShellState();
}

class _ToolsShellState extends State<ToolsShell> {
  late Section at = widget.initial;

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final size = MediaQuery.sizeOf(context);
      final phone = usePhoneLayout(context) || size.height < 1000;
      final body = KeyedSubtree(key: ValueKey('section-${at.name}'), child: sectionBody(at));
      if (phone) {
        const shown = [Section.today, Section.teach, Section.tools, Section.library, Section.reports, Section.settings];
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(at == Section.board ? 0 : 32, at == Section.board ? 0 : 24, at == Section.board ? 0 : 32, 0),
              child: body,
            ),
          ),
          bottomNavigationBar: Container(
            color: S.ink,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 150,
                child: Row(children: [
                  _barItem(l, null, phone: true),
                  for (final s in shown) _barItem(l, s, phone: true),
                ]),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 250,
            color: S.ink,
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: IntrinsicHeight(child: Column(children: [
              Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(34)),
                alignment: Alignment.center,
                child: Text('Z', style: hd(70, c: S.ink, w: FontWeight.w800)),
              ),
              const SizedBox(height: 28),
              _barItem(l, null),
              for (final s in Section.values.where((s) => s != Section.settings)) _barItem(l, s),
              const Spacer(),
              _barItem(l, Section.settings),
              if (school.current != null) ...[
                const SizedBox(height: 20),
                teacherFace(school.current!, size: 96, ring: Colors.white),
                const SizedBox(height: 10),
                Text(school.current!.firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(26, c: Colors.white, w: FontWeight.w600)),
              ],
            ]))))),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(padding: at == Section.board ? EdgeInsets.zero : const EdgeInsets.fromLTRB(100, 56, 100, 0), child: body),
            ),
          ),
        ]),
      );
    },
  );

  /// A rail (or bar) item; null is Home.
  Widget _barItem(Lang l, Section? s, {bool phone = false}) {
    final (icon, label) = s == null ? (Icons.home_rounded, const L10n('Home', 'ಮುಖಪುಟ')) : sectionLabel(s);
    final on = s == at;
    final item = Press(
      key: ValueKey('rail-${s?.name ?? 'home'}'),
      radius: 36,
      onTap: () => s == null ? Navigator.of(context).maybePop() : setState(() => at = s),
      child: Container(
        width: phone ? null : 196,
        padding: EdgeInsets.symmetric(vertical: phone ? 10 : 16),
        decoration: BoxDecoration(color: on ? S.violet : Colors.transparent, borderRadius: BorderRadius.circular(36)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: phone ? 48 : 56, color: Colors.white.withValues(alpha: on ? 1 : .78)),
          const SizedBox(height: 8),
          Text(label.t(l), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx(phone ? 20 : 26, c: Colors.white.withValues(alpha: on ? 1 : .78), w: on ? FontWeight.w700 : FontWeight.w500, h: 1.1)),
        ]),
      ),
    );
    return phone ? Expanded(child: Padding(padding: const EdgeInsets.all(6), child: item)) : Padding(padding: const EdgeInsets.only(bottom: 10), child: item);
  }
}
