import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Several fields/buttons sit below the fold of a step's ListView on the
/// default test viewport. tester.tap() hit-tests a widget's on-screen
/// position regardless of whether it is actually scrolled into view, so an
/// off-screen target silently taps whatever is painted at that offset
/// instead. Always scroll it into view first.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls a keyed widget into view without tapping it. A ListView's sliver
/// only builds elements for children within its viewport plus cache extent
/// (whether or not the list was constructed with a fixed `children:` list),
/// so a widget below the fold - e.g. the payment amount summary card,
/// several list items down - is simply absent from the element tree, and
/// invisible to `find`, until something scrolls it into range. Unlike
/// ensureVisible (which needs the element to already exist to know where to
/// scroll to), scrollUntilVisible scrolls blindly in increments and
/// re-checks after each one, so it works even when the target has not been
/// built yet.
Future<void> scrollToKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(finder, 200);
  await tester.pumpAndSettle();
}

/// For UI changes driven by real sqflite (FFI) I/O kicked off inside a
/// button's onPressed handler (whose returned Future the framework does not
/// track - onPressed is a plain VoidCallback). tester.pump(duration) only
/// advances the *simulated* clock; it does not block for `duration` of real
/// wall-clock time, so a bounded loop of pump() calls finishes in a couple
/// of real milliseconds regardless of the requested duration - nowhere near
/// enough for a real FFI round trip (observed ~100-150ms even for a single
/// row). A real `Future.delayed` is what actually lets that wall-clock time
/// pass; it only works because the caller is inside tester.runAsync().
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 60}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsOneWidget, reason: 'gave up waiting after $maxTries pumps');
}
