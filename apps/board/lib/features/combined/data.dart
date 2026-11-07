import 'package:flutter/material.dart';

import 'kit.dart';

/// Sample school data for the combined classroom: staff cards, today's timetable, chapters and
/// the resources each topic carries (real lesson titles and Kinetix ids from the content packs).
/// Students appear only as roll numbers.
class Teacher {
  const Teacher(this.name, this.initials, this.subj, this.now, this.color);
  final String name, initials, now;
  final Subj subj;
  final Color color;
}

const teachers = [
  Teacher('K. Meera', 'KM', Subj.physics, '1st PUC A · Physics · now', Color(0xFF2457E6)),
  Teacher('S. Prakash', 'SP', Subj.chemistry, '1st PUC B · Chemistry · now', Color(0xFF00876A)),
  Teacher('A. Farah', 'AF', Subj.maths, '2nd PUC A · Maths · 10:55', Color(0xFF7A4FD6)),
  Teacher('R. Venkatesh', 'RV', Subj.biology, '1st PUC A · Biology · 12:00', Color(0xFF3C9A3C)),
  Teacher('N. Kavya', 'NK', Subj.cs, '2nd PUC C · Comp. Sci. · 2:00', Color(0xFFD55E00)),
];

class Period {
  const Period(this.no, this.time, this.cls, this.what, this.subj, this.state);
  final int no;
  final String time, cls, what;
  final Subj subj;

  /// done, now, next, later, lab
  final String state;
}

const today = [
  Period(1, '8:50', '1st PUC C', 'Gravitation · Kepler’s laws', Subj.physics, 'done'),
  Period(2, '9:45', '1st PUC A', 'Gravitation · g and its variation', Subj.physics, 'now'),
  Period(3, '10:55', '2nd PUC A', 'Ray optics · Refraction of light', Subj.physics, 'next'),
  Period(4, '12:00', '1st PUC B', 'Laws of motion · Friction', Subj.physics, 'later'),
  Period(5, '2:00', '1st PUC A', 'Practical · Simple pendulum', Subj.physics, 'lab'),
];

class ChTopic {
  const ChTopic(this.no, this.title, this.minutes, this.res, {this.state = 'todo', this.items = const [], this.video});
  final int no, minutes;
  final String title, state;
  final List<Res> res;
  final List<String> items;
  final String? video;
}

/// 1st PUC Chemistry · chapter 1 (puc1-chemistry-some-basic-concepts-of-chemistry), with the
/// Zynetix School episodes mapped to its topics (src/content/videos/drive.ts, Chemistry 1–13).
const chemChapter = [
  ChTopic(1, 'Matter, its properties and measurement', 40, [Res.lesson, Res.video, Res.interactive, Res.sim, Res.lab, Res.practice], state: 'done', items: ['Sim: states-of-matter', 'Lab: ink-chromatography'], video: 'Ep 1–5 · Nature and classification of matter'),
  ChTopic(2, 'Uncertainty in measurement', 40, [Res.lesson, Res.video, Res.interactive, Res.model3d, Res.practice], state: 'done', items: ['3D: lab_apparatus'], video: 'Ep 5 · Measurement, SI units and uncertainty'),
  ChTopic(3, 'Laws of chemical combination and Dalton’s atomic theory', 40, [Res.lesson, Res.video, Res.interactive, Res.practice], state: 'done', video: 'Ep 6–7 · Laws of chemical combination'),
  ChTopic(4, 'Atomic mass, mole concept and percentage composition', 40, [Res.lesson, Res.video, Res.interactive, Res.explainer, Res.practice], state: 'now', items: ['Mole calculator', 'The mole map'], video: 'Ep 8–11 · Mole concept and molar mass'),
  ChTopic(5, 'Stoichiometry, limiting reagent and concentration', 40, [Res.lesson, Res.video, Res.interactive, Res.lab, Res.practice], items: ['Lab: titration-oxalic-naoh'], video: 'Ep 12–13 · Limiting reagent'),
];

/// 1st PUC Physics · Gravitation (puc1-physics-gravitation): the subject kit's real ids.
const gravityTopics = [
  'Kepler’s laws of planetary motion',
  'Universal law of gravitation',
  'Acceleration due to gravity and its variation',
  'Gravitational potential energy and escape speed',
  'Earth satellites and the energy of an orbiting satellite',
];

class LibItem {
  const LibItem(this.kind, this.title, this.sub, this.id, this.art, this.subj, {this.offline = true});
  final Res kind;
  final String title, sub, id;
  final Art art;
  final Subj subj;
  final bool offline;
}

const library = [
  LibItem(Res.model3d, 'Solar system', 'Gravitation · Kepler’s laws', 'solar_system', Art.orbit, Subj.physics),
  LibItem(Res.model3d, 'Layers of the Earth', 'Gravitation · g with depth', 'earth_layers', Art.earth, Subj.physics),
  LibItem(Res.lab, 'The simple pendulum', 'Measure g from T² against L', 'pendulum', Art.pendulum, Subj.physics),
  LibItem(Res.sim, 'Projectile motion', 'Motion in a straight line · free fall', 'projectile-motion', Art.graph, Subj.physics),
  LibItem(Res.lab, 'Force along an inclined plane', 'Laws of motion', 'inclined-plane', Art.graph, Subj.physics),
  LibItem(Res.model3d, 'Lens on an optical bench', 'Ray optics · lenses', 'lens_bench', Art.lens, Subj.physics),
  LibItem(Res.model3d, 'Molecules · H₂O', 'Chemical bonding · VSEPR', 'molecules', Art.molecule, Subj.chemistry),
  LibItem(Res.lab, 'Standardising NaOH with oxalic acid', 'Basic concepts · concentration', 'titration-oxalic-naoh', Art.flask, Subj.chemistry),
  LibItem(Res.sim, 'Atomic structure', 'Structure of atom · models', 'atomic-structure', Art.atom, Subj.chemistry),
  LibItem(Res.lab, 'Flame tests for metal ions', 'Structure of atom · spectra', 'flame-test', Art.flask, Subj.chemistry),
  LibItem(Res.explainer, 'Gravity and falling: feather vs hammer', 'Explainer · 6 scenes', 'gravity-falling', Art.pendulum, Subj.physics),
  LibItem(Res.video, 'Ep 9 · Mole concept and molar mass', 'Concept video · Chemistry', 'ep09', Art.molecule, Subj.chemistry, offline: false),
];
