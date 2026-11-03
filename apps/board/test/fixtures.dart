// Blocks and questions in the newer schema formats (whiteboard, interactive, multi_correct,
// numeric), for tests and screenshots, until the seed packs carry them.
import 'package:zynetix_board/engine/model.dart';

Block whiteboardBlock() => Block(BlockType.whiteboard, {
      'id': 'wb1',
      'type': 'whiteboard',
      'title': {'en': 'Graph of a quadratic', 'kn': 'ವರ್ಗ ಸಮೀಕರಣದ ನಕ್ಷೆ'},
      'steps': [
        {
          'say': {'en': 'Take y equals x squared minus two x minus three.'},
          'draw': [
            {'kind': 'text', 'at': [4, 3], 'text': {'en': 'Plot the quadratic'}, 'size': 3.4, 'color': 'yellow'},
            {'kind': 'math', 'at': [4, 10], 'tex': r'y = x^2 - 2x - 3', 'size': 3.2},
          ],
        },
        {
          'say': {'en': 'Draw the axes, and the curve. It is a parabola opening upward.'},
          'draw': [
            {'kind': 'axes', 'from': [46, 4], 'to': [96, 56], 'x': [-3, 5], 'y': [-5, 6], 'xLabel': 'x', 'yLabel': 'y'},
            {'kind': 'plot', 'fn': 'x^2 - 2*x - 3', 'color': 'yellow'},
          ],
        },
        {
          'say': {'en': 'It cuts the x axis at minus one and three: the roots.'},
          'draw': [
            {'kind': 'circle', 'at': [58.5, 32.4], 'r': 1.2, 'color': 'red', 'fill': true},
            {'kind': 'circle', 'at': [83.5, 32.4], 'r': 1.2, 'color': 'red', 'fill': true},
            {'kind': 'math', 'at': [4, 20], 'tex': r'(x+1)(x-3) = 0', 'size': 3, 'color': 'green'},
            {'kind': 'arrow', 'from': [30, 24], 'to': [56.6, 31.6], 'color': 'red', 'dashed': true},
          ],
        },
        {
          'say': {'en': 'The vertex is at x equals one.'},
          'draw': [
            {'kind': 'line', 'from': [71, 4], 'to': [71, 56], 'color': 'blue', 'dashed': true},
            {'kind': 'text', 'at': [4, 32], 'text': {'en': 'Vertex at x = 1'}, 'size': 3, 'color': 'blue'},
            {'kind': 'rect', 'from': [2, 30], 'to': [36, 38], 'color': 'blue'},
          ],
        },
      ],
    });

Block interactiveBlock(String kind) => Block(BlockType.interactive, {
      'id': 'ia-$kind',
      'type': 'interactive',
      'kind': kind,
      'caption': {'en': switch (kind) {
        'function_plot' => r'Move $a$ and $b$: the parabola $y = ax^2 + b$ opens wider or narrower, and moves up or down.',
        'vectors' => 'Two forces on one point. The yellow arrow is their resultant.',
        'unit_circle' => 'Turn the angle: sin is the height of P, cos is how far across.',
        _ => 'Move the sliders and watch the values change.',
      }},
      'sliders': switch (kind) {
        'unit_circle' => [
            {'name': 'theta', 'label': {'en': 'θ'}, 'min': 0, 'max': 360, 'step': 1, 'value': 40, 'unit': '°'},
          ],
        _ => [
            {'name': 'a', 'label': {'en': r'$a$'}, 'min': -3, 'max': 3, 'step': 0.1, 'value': 1},
            {'name': 'b', 'label': {'en': r'$b$'}, 'min': -5, 'max': 5, 'step': 0.5, 'value': 2},
          ],
      },
      'fns': [
        {'fn': 'a*x^2 + b', 'label': 'y = ax² + b', 'color': 'yellow'},
        {'fn': 'x^2', 'label': 'y = x²', 'color': 'blue'},
      ],
      'x': kind == 'number_line' ? [-6, 6] : [-5, 5],
      'y': [-6, 10],
      'vectors': [
        ['a*2', 1],
        [-1, 'b'],
      ],
      'data': {'Rent': 'b*10+60', 'Food': 40, 'Travel': 'a*10+20', 'Books': 15},
      'points': ['a', 'b', 2.5],
      'readouts': kind == 'unit_circle'
          ? []
          : [
              {'label': {'en': 'Value at x = 2'}, 'expr': 'a*4 + b', 'digits': 2},
              {'label': {'en': 'a × b'}, 'expr': 'a*b', 'digits': 1},
            ],
      'tryThis': [
        {'en': r'Make $a$ negative. What happens?'},
        {'en': r'Set $b = 0$.'},
      ],
    });

Lesson lessonWith(InstalledPack pack, List<Block> blocks) => Lesson(
      id: 'test-lesson',
      chapterId: pack.chapter.id,
      topicId: pack.chapter.topics.first.id,
      title: const L10n('Board and interactives'),
      minutes: 40,
      blocks: blocks,
    );

Question multiQuestion() => Question.fromJson({
      'id': 'mc1',
      'chapterId': 'x',
      'stem': {'en': 'Which of these are vector quantities?'},
      'options': [
        {'en': 'Velocity'},
        {'en': 'Speed'},
        {'en': 'Force'},
        {'en': 'Mass'},
      ],
      'answer': 0,
      'answers': [0, 2],
      'exams': ['JEE_ADV'],
      'difficulty': 'medium',
      'format': 'multi_correct',
      'explanation': {'en': 'Velocity and force have direction; speed and mass do not.'},
    });

Question numericQuestion() => Question.fromJson({
      'id': 'nm1',
      'chapterId': 'x',
      'stem': {'en': 'A car goes from 0 to 20 m/s in 8 s. Its acceleration, in m/s², is'},
      'options': [],
      'answer': 0,
      'numericAnswer': 2.5,
      'tolerance': 0.05,
      'exams': ['JEE'],
      'difficulty': 'easy',
      'format': 'numeric',
      'explanation': {'en': 'a = (20 − 0) / 8 = 2.5 m/s²'},
    });
