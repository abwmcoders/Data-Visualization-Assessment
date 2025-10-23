import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/main.dart';
import 'package:wearable_device/viewmodels/biometrics_viewmodel.dart';


void main() {
  testWidgets('Range switch updates charts and syncs tooltips', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(create: (_) => BiometricsViewModel()..loadData(), child: const MyApp()),
    );
    await tester.pumpAndSettle();
    // Find 90d button (initial), tap 7d
    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();
    // Verify axis domain changed (check via debug or key)
    expect(
      find.byKey(const Key('x-axis-min')),
      equals(DateTime.now().subtract(Duration(days: 7))),
    ); // Pseudo-check; use actual finder
    // Simulate tap on chart, check selectedDate synced across
  });
}

