import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const motion = 'puc1-physics-02-motion-in-a-straight-line';
  test('Continue starts at the first topic of the syllabus for a new class', () async {
    final s = await testServices();
    expect(s.nextTopic()!.lesson.topicId, 'puc1-physics-01-units-and-measurement.t1');
  });
  test('Continue stays in the chapter being taught, then moves to the next chapter', () async {
    var s = await testServices(prefs: {'taught': ['$motion.t1', '$motion.t2']});
    expect(s.nextTopic()!.lesson.topicId, '$motion.t3');
    s = await testServices(prefs: {'taught': [for (var i = 1; i <= 5; i++) '$motion.t$i']});
    expect(s.nextTopic()!.lesson.topicId, 'puc1-physics-03-motion-in-a-plane.t1');
  });
}
