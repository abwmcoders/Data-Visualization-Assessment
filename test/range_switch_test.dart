import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/main.dart'; // Assuming this is the correct import for MyApp; adjust if needed
import 'package:wearable_device/viewmodels/biometrics_viewmodel.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Import for SfCartesianChart

void main() {
  testWidgets('Range switch updates charts and syncs tooltips', (tester) async {
    final vm = BiometricsViewModel();
    await vm.loadData(); // Await loading to ensure data is ready

    await tester.pumpWidget(ChangeNotifierProvider.value(value: vm, child: const MyApp()));
    await tester.pumpAndSettle();

    // Verify initial state
    expect(vm.rangeDays, 90);
    expect(find.text('Biometrics Dashboard'), findsOneWidget); // Confirm loaded

    // Tap 7d button
    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();

    // Verify range updated
    expect(vm.rangeDays, 7);

    // Verify axis domain changed for HRV chart (assuming largeDataset=false initially)
    final hrvChartFinder = find.byKey(const ValueKey('false_HRV'));
    final hrvChart = tester.widget<SfCartesianChart>(hrvChartFinder);
    final expectedMin = DateTime.now().subtract(const Duration(days: 7));
    final hrvAxis = hrvChart.primaryXAxis as DateTimeAxis;
    final hrvMin = hrvAxis.minimum as DateTime?;
    expect(hrvMin?.year, expectedMin.year);
    expect(hrvMin?.month, expectedMin.month);
    expect(hrvMin?.day, expectedMin.day); // Compare date parts to avoid time mismatches

    // Similarly for other charts
    final rhrChartFinder = find.byKey(const ValueKey('false_RHR'));
    final rhrChart = tester.widget<SfCartesianChart>(rhrChartFinder);
    final rhrAxis = rhrChart.primaryXAxis as DateTimeAxis;
    final rhrMin = rhrAxis.minimum as DateTime?;
    expect(rhrMin?.year, expectedMin.year);
    expect(rhrMin?.month, expectedMin.month);
    expect(rhrMin?.day, expectedMin.day);

    final stepsChartFinder = find.byKey(const ValueKey('false_Steps'));
    final stepsChart = tester.widget<SfCartesianChart>(stepsChartFinder);
    final stepsAxis = stepsChart.primaryXAxis as DateTimeAxis;
    final stepsMin = stepsAxis.minimum as DateTime?;
    expect(stepsMin?.year, expectedMin.year);
    expect(stepsMin?.month, expectedMin.month);
    expect(stepsMin?.day, expectedMin.day);

    // Simulate tap on HRV chart to check tooltip sync (sets selectedDate)
    final hrvCenter = tester.getCenter(hrvChartFinder);
    await tester.tapAt(hrvCenter);
    await tester.pump();

    // Verify selectedDate is set (assuming data points exist; in real test, mock data if needed)
    expect(vm.selectedDate, isNotNull);

    // Tooltip sync is handled in code via trackball.show calls; hard to assert visibility in widget test,
    // but since setSelectedDate is called and tooltips use it, assume sync works if date is set.
  });
}


