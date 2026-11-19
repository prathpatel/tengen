import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/result.dart';

void main() {
  test('OGS outcomes', () {
    var r = describeResult(outcome: '17.5 points', winner: StoneColor.white);
    expect((r.short, r.description), ('W+17.5', 'White wins by 17.5 points'));
    r = describeResult(outcome: 'Resignation', winner: StoneColor.black);
    expect((r.short, r.description), ('B+R', 'White resigned · Black is victorious'));
    r = describeResult(outcome: 'Timeout', winner: StoneColor.white);
    expect(r.short, 'W+T');
    expect(r.description, startsWith('Black ran out of time'));
    r = describeResult(outcome: 'Server Decision', winner: StoneColor.black);
    expect(r.description, startsWith('Black wins by server decision'));
    r = describeResult(outcome: 'Cancellation', winner: null);
    expect(r.short, 'Cancelled');
  });

  test('local result strings', () {
    expect(describeResult(outcome: 'W+6.5', winner: null).description, 'White wins by 6.5 points');
    expect(describeResult(outcome: 'B+R', winner: null).short, 'B+R');
    expect(describeResult(outcome: 'Jigo', winner: null).short, 'Jigo');
  });
}
