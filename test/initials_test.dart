import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/models/models.dart';

void main() {
  test('initials take the first and last words', () {
    expect(initialsOf('Jodie Marsh'), 'JM');
    expect(initialsOf('Mary Jane Watson'), 'MW');
    expect(initialsOf('  ama   boateng '), 'AB');
  });

  test('one camel-cased word takes its capitals', () {
    // The demo account. The decoder used to make this "SH".
    expect(initialsOf('ShiftAi'), 'SA');
    expect(initialsOf('iPhone'), 'IP');
  });

  test('one plain word takes two letters, and nothing takes none', () {
    expect(initialsOf('Priya'), 'PR');
    expect(initialsOf('x'), 'X');
    expect(initialsOf('   '), '');
  });
}
