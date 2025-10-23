import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/data_service.dart';
import '../viewmodels/biometrics_viewmodel.dart';
import '../models/biometric.dart';

class BiometricChart extends StatelessWidget {
  final String title;
  final String Function(Biometric) valueSelector;
  final String unit;

  const BiometricChart({super.key, required this.title, required this.valueSelector, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Consumer<BiometricsViewModel>(
      builder: (context, vm, child) {
        var data = vm.getFilteredData();
        return SfCartesianChart(
          primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat('MMM dd'),
            minimum: DateTime.now().subtract(Duration(days: vm.rangeDays)),
            maximum: DateTime.now(),
          ),
          zoomPanBehavior: ZoomPanBehavior(enablePanning: true, enablePinching: true),
          trackballBehavior: TrackballBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
            builder: (context, details) {
              // Access point via groupingModeInfo for groupAllPoints mode, fallback to point
              final point = details.groupingModeInfo?.points.firstOrNull ?? details.point;
              if (point != null) {
                vm.setSelectedDate(point.x as DateTime?);
                return Text('${point.x}: ${point.y} $unit');
              }
              return const SizedBox.shrink();
            },
          ),
          series: <CartesianSeries<dynamic, DateTime>>[
            LineSeries<Biometric, DateTime>(
              dataSource: data,
              xValueMapper: (Biometric b, _) => b.date,
              yValueMapper: (Biometric b, _) => double.tryParse(valueSelector(b)) ?? 0,
            ),
            // Add bands for HRV only
            if (title == 'HRV')
              RangeAreaSeries<Map<String, double?>, DateTime>(
                dataSource: DataService().calculateBands(data),
                xValueMapper: (band, _) => DateTime.fromMillisecondsSinceEpoch(band['date']!.toInt()),
                lowValueMapper: (band, _) => band['low'],
                highValueMapper: (band, _) => band['high'],
                opacity: 0.3,
              ),
          ],
          annotations: vm.journals
              .map(
                (j) => CartesianChartAnnotation(
                  coordinateUnit: CoordinateUnit.point,
                  region: AnnotationRegion.chart,
                  x: j.date,
                  y: 0, // Position at bottom; adjust if your y-axis min is not 0
                  verticalAlignment: ChartAlignment.near,
                  widget: GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(title: Text(j.note), content: Text('Mood: ${j.mood}')),
                    ),
                    child: Container(
                      color: Colors.red,
                      width: 2,
                      height: double.infinity, // Attempts to span vertically; may need clipping adjustment
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

