import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../viewmodels/biometrics_viewmodel.dart';
import '../models/biometric.dart';
import '../services/data_service.dart';

/*
Perf Note: To handle performance for longer ranges (30d/90d) and large datasets (10k+ points), we apply LTTB (Largest Triangle Three Buckets) downsampling when range >=30d and data.length > 1000, reducing to 1000 points while preserving visual shape. This ensures smooth rendering with frame times under 16ms. Optimizations include disabling chart animations, forcing widget recreation with keys, and synchronizing zoom/pan without redundant renders.
*/

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late TrackballBehavior _hrvTrackball;
  late TrackballBehavior _rhrTrackball;
  late TrackballBehavior _stepsTrackball;

  ChartSeriesController? _hrvSeriesController;
  ChartSeriesController? _rhrSeriesController;
  ChartSeriesController? _stepsSeriesController;

  DateTimeAxisController? _hrvAxisController;
  DateTimeAxisController? _rhrAxisController;
  DateTimeAxisController? _stepsAxisController;

  late ZoomPanBehavior _hrvZoom;
  late ZoomPanBehavior _rhrZoom;
  late ZoomPanBehavior _stepsZoom;

  bool _hrvInteractive = false;
  bool _rhrInteractive = false;
  bool _stepsInteractive = false;

  @override
  void initState() {
    super.initState();
    _hrvTrackball = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      builder: (context, details) => _tooltipBuilder(context, details, 'ms'),
    );
    _rhrTrackball = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      builder: (context, details) => _tooltipBuilder(context, details, 'bpm'),
    );
    _stepsTrackball = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      builder: (context, details) => _tooltipBuilder(context, details, 'steps'),
    );

    _hrvZoom = ZoomPanBehavior(enablePanning: true, enablePinching: true, zoomMode: ZoomMode.x);
    _rhrZoom = ZoomPanBehavior(enablePanning: true, enablePinching: true, zoomMode: ZoomMode.x);
    _stepsZoom = ZoomPanBehavior(enablePanning: true, enablePinching: true, zoomMode: ZoomMode.x);
  }

  Widget _tooltipBuilder(BuildContext context, TrackballDetails details, String unit) {
    final point = details.groupingModeInfo?.points.firstOrNull ?? details.point;
    if (point != null) {
      Provider.of<BiometricsViewModel>(context, listen: false).setSelectedDate(point.x as DateTime?);
      final dateStr = DateFormat('MMM dd').format(point.x as DateTime);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Text('$dateStr: ${point.y} $unit'),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BiometricsViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return Scaffold(
            body: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: const Center(child: Text('Loading...')),
            ),
          );
        }
        if (vm.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(vm.error!),
                  ElevatedButton(onPressed: vm.loadData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        if (vm.biometrics.isEmpty) {
          return const Scaffold(body: Center(child: Text('No data available')));
        }
        bool isWide = MediaQuery.of(context).size.width > 400;
        return Scaffold(
          appBar: AppBar(title: const Text('Biometrics Dashboard')),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [7, 30, 90]
                          .map(
                            (d) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  vm.setRange(d);
                                  final min = DateTime.now().subtract(Duration(days: d));
                                  final max = DateTime.now();
                                  // Reset zoom on range switch
                                  _hrvAxisController?.visibleMinimum = min;
                                  _hrvAxisController?.visibleMaximum = max;
                                  _hrvAxisController?.zoomFactor = 1.0;
                                  _hrvAxisController?.zoomPosition = 0.0;
                                  _rhrAxisController?.visibleMinimum = min;
                                  _rhrAxisController?.visibleMaximum = max;
                                  _rhrAxisController?.zoomFactor = 1.0;
                                  _rhrAxisController?.zoomPosition = 0.0;
                                  _stepsAxisController?.visibleMinimum = min;
                                  _stepsAxisController?.visibleMaximum = max;
                                  _stepsAxisController?.zoomFactor = 1.0;
                                  _stepsAxisController?.zoomPosition = 0.0;
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Text('${d}d'),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Large Dataset (10k+)'),
                      value: vm.largeDataset,
                      onChanged: vm.toggleLargeDataset,
                      activeColor: Theme.of(context).colorScheme.primary,
                      tileColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        children: _chartCards(vm).map((card) => Expanded(child: card)).toList(),
                      )
                    else
                      Column(
                        children: _chartCards(vm),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _chartCards(BiometricsViewModel vm) => [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HRV', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: _buildChart(
                    vm: vm,
                    title: 'HRV',
                    valueSelector: (b) => b.hrv ?? 0,
                    unit: 'ms',
                    trackball: _hrvTrackball,
                    zoom: _hrvZoom,
                    seriesCreated: (controller) => _hrvSeriesController = controller,
                    axisCreated: (controller) => _hrvAxisController = controller,
                    touchDown: () => _hrvInteractive = true,
                    touchUp: () {
                      _hrvInteractive = false;
                      _rhrTrackball.hide();
                      _stepsTrackball.hide();
                    },
                    trackballChanging: (args) {
                      if (_hrvInteractive && args.chartPointInfo.chartPoint != null) {
                        final position = _rhrSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _rhrTrackball.show(position.dx, position.dy, 'pixel');
                        final position2 = _stepsSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _stepsTrackball.show(position2.dx, position2.dy, 'pixel');
                      }
                    },
                    zooming: (args) {
                      if (args.axis!.name == 'primaryXAxis') {
                        _rhrAxisController?.zoomFactor = args.currentZoomFactor;
                        _rhrAxisController?.zoomPosition = args.currentZoomPosition;
                        _stepsAxisController?.zoomFactor = args.currentZoomFactor;
                        _stepsAxisController?.zoomPosition = args.currentZoomPosition;
                      }
                    },
                    isHrv: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RHR', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: _buildChart(
                    vm: vm,
                    title: 'RHR',
                    valueSelector: (b) => (b.rhr ?? 0).toDouble(),
                    unit: 'bpm',
                    trackball: _rhrTrackball,
                    zoom: _rhrZoom,
                    seriesCreated: (controller) => _rhrSeriesController = controller,
                    axisCreated: (controller) => _rhrAxisController = controller,
                    touchDown: () => _rhrInteractive = true,
                    touchUp: () {
                      _rhrInteractive = false;
                      _hrvTrackball.hide();
                      _stepsTrackball.hide();
                    },
                    trackballChanging: (args) {
                      if (_rhrInteractive && args.chartPointInfo.chartPoint != null) {
                        final position = _hrvSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _hrvTrackball.show(position.dx, position.dy, 'pixel');
                        final position2 = _stepsSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _stepsTrackball.show(position2.dx, position2.dy, 'pixel');
                      }
                    },
                    zooming: (args) {
                      if (args.axis!.name == 'primaryXAxis') {
                        _hrvAxisController?.zoomFactor = args.currentZoomFactor;
                        _hrvAxisController?.zoomPosition = args.currentZoomPosition;
                        _stepsAxisController?.zoomFactor = args.currentZoomFactor;
                        _stepsAxisController?.zoomPosition = args.currentZoomPosition;
                      }
                    },
                    isHrv: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Steps', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: _buildChart(
                    vm: vm,
                    title: 'Steps',
                    valueSelector: (b) => (b.steps ?? 0).toDouble(),
                    unit: 'steps',
                    trackball: _stepsTrackball,
                    zoom: _stepsZoom,
                    seriesCreated: (controller) => _stepsSeriesController = controller,
                    axisCreated: (controller) => _stepsAxisController = controller,
                    touchDown: () => _stepsInteractive = true,
                    touchUp: () {
                      _stepsInteractive = false;
                      _hrvTrackball.hide();
                      _rhrTrackball.hide();
                    },
                    trackballChanging: (args) {
                      if (_stepsInteractive && args.chartPointInfo.chartPoint != null) {
                        final position = _hrvSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _hrvTrackball.show(position.dx, position.dy, 'pixel');
                        final position2 = _rhrSeriesController!.pointToPixel(args.chartPointInfo.chartPoint!);
                        _rhrTrackball.show(position2.dx, position2.dy, 'pixel');
                      }
                    },
                    zooming: (args) {
                      if (args.axis!.name == 'primaryXAxis') {
                        _hrvAxisController?.zoomFactor = args.currentZoomFactor;
                        _hrvAxisController?.zoomPosition = args.currentZoomPosition;
                        _rhrAxisController?.zoomFactor = args.currentZoomFactor;
                        _rhrAxisController?.zoomPosition = args.currentZoomPosition;
                      }
                    },
                    isHrv: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];

  Widget _buildChart({
    required BiometricsViewModel vm,
    required String title,
    required double Function(Biometric) valueSelector,
    required String unit,
    required TrackballBehavior trackball,
    required ZoomPanBehavior zoom,
    required void Function(ChartSeriesController) seriesCreated,
    required void Function(DateTimeAxisController) axisCreated,
    required void Function() touchDown,
    required void Function() touchUp,
    required void Function(TrackballArgs) trackballChanging,
    required void Function(ZoomPanArgs) zooming,
    required bool isHrv,
  }) {
    var data = vm.getFilteredData();
    if (vm.rangeDays >= 30 && data.length > 1000) {
      data = _lttbDownsample(data, 1000);
    }
    return SfCartesianChart(
      key: ValueKey('${vm.largeDataset}_$title'), // Key to force recreation
      primaryXAxis: DateTimeAxis(
        name: 'primaryXAxis',
        dateFormat: DateFormat('MMM dd'),
        minimum: DateTime.now().subtract(Duration(days: vm.rangeDays)),
        maximum: DateTime.now(),
        onRendererCreated: axisCreated,
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 6),
        minorTickLines: const MinorTickLines(size: 4),
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 6),
        minorTickLines: const MinorTickLines(size: 4),
      ),
      zoomPanBehavior: zoom,
      trackballBehavior: trackball,
      onChartTouchInteractionDown: (_) => touchDown(),
      onChartTouchInteractionUp: (_) => touchUp(),
      onTrackballPositionChanging: trackballChanging,
      onZooming: zooming,
      series: <CartesianSeries>[
        LineSeries<Biometric, DateTime>(
          dataSource: data,
          xValueMapper: (Biometric b, _) => b.date,
          yValueMapper: (Biometric b, _) => valueSelector(b),
          onRendererCreated: seriesCreated,
          markerSettings: const MarkerSettings(isVisible: true, shape: DataMarkerType.circle, borderWidth: 2),
          width: 2,
          color: Theme.of(context).colorScheme.primary,
          animationDuration: 0, // Disable animation to avoid disposal issue
        ),
        if (isHrv)
          RangeAreaSeries<Map<String, double?>, DateTime>(
            dataSource: DataService().calculateBands(data),
            xValueMapper: (band, _) => DateTime.fromMillisecondsSinceEpoch(band['date']!.toInt()),
            lowValueMapper: (band, _) => band['low'],
            highValueMapper: (band, _) => band['high'],
            opacity: 0.3,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
                Theme.of(context).colorScheme.primary.withOpacity(0.0),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            animationDuration: 0, // Disable animation
          ),
      ],
      annotations: vm.journals
          .map(
            (j) => CartesianChartAnnotation(
              coordinateUnit: CoordinateUnit.point,
              region: AnnotationRegion.chart,
              x: j.date,
              y: 0,
              verticalAlignment: ChartAlignment.near,
              widget: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(title: Text(j.note), content: Text('Mood: ${j.mood}')),
                ),
                child: Container(color: Colors.red, width: 2, height: double.infinity),
              ),
            ),
          )
          .toList(),
    );
  }

  List<Biometric> _lttbDownsample(List<Biometric> data, int threshold) {
    if (data.length <= threshold) {
      return List.from(data);
    }
    if (threshold < 3) {
      threshold = 3;
    }

    // Compute min and max for each series
    double minHrv = double.infinity, maxHrv = -double.infinity;
    double minRhr = double.infinity, maxRhr = -double.infinity;
    double minSteps = double.infinity, maxSteps = -double.infinity;
    for (var b in data) {
      if (b.hrv != null) {
        minHrv = math.min(minHrv, b.hrv!);
        maxHrv = math.max(maxHrv, b.hrv!);
      }
      if (b.rhr != null) {
        // Ensure rhr is treated as double (handles int or double types)
        final double rhrVal = (b.rhr is double) ? b.rhr as double : (b.rhr as num).toDouble();
        minRhr = math.min(minRhr, rhrVal);
        maxRhr = math.max(maxRhr, rhrVal);
      }
      if (b.steps != null) {
        // Ensure steps is treated as double (handles int or double types)
        final double stepsVal = (b.steps is double) ? b.steps as double : (b.steps as num).toDouble();
        minSteps = math.min(minSteps, stepsVal);
        maxSteps = math.max(maxSteps, stepsVal);
      }
    }

    bool hasHrv = maxHrv > -double.infinity;
    bool hasRhr = maxRhr > -double.infinity;
    bool hasSteps = maxSteps > -double.infinity;

    if (!hasHrv && !hasRhr && !hasSteps) {
      return data.sublist(0, threshold);
    }

    double rangeHrv = hasHrv ? (maxHrv - minHrv) : 0;
    double rangeRhr = hasRhr ? (maxRhr - minRhr) : 0;
    double rangeSteps = hasSteps ? (maxSteps - minSteps) : 0;

    int countSeries = (hasHrv ? 1 : 0) + (hasRhr ? 1 : 0) + (hasSteps ? 1 : 0);

    // Compute combined normalized y values
    List<double> ys = [];
    for (var b in data) {
      double sumNorm = 0.0;
      if (hasHrv) {
        // guard division by zero
        sumNorm += ((b.hrv ?? minHrv) - minHrv) / (rangeHrv == 0 ? 1 : rangeHrv);
      }
      if (hasRhr) {
        final double rhrVal = b.rhr != null
            ? ((b.rhr is double) ? b.rhr as double : (b.rhr as num).toDouble())
            : minRhr;
        sumNorm += ((rhrVal) - minRhr) / (rangeRhr == 0 ? 1 : rangeRhr);
      }
      if (hasSteps) {
        final double stepsVal = b.steps != null
            ? ((b.steps is double) ? b.steps as double : (b.steps as num).toDouble())
            : minSteps;
        sumNorm += ((stepsVal) - minSteps) / (rangeSteps == 0 ? 1 : rangeSteps);
      }
      ys.add(sumNorm / countSeries);
    }

    List<double> xs = data.map((b) => b.date.millisecondsSinceEpoch.toDouble()).toList();

    // Get selected indices using LTTB
    List<int> selectedIndices = _lttbIndices(xs, ys, threshold);

    // Return selected data points
    return selectedIndices.map((i) => data[i]).toList();
  }

  List<int> _lttbIndices(List<double> xs, List<double> ys, int threshold) {
    int n = xs.length;
    if (threshold >= n || threshold <= 0) {
      return List.generate(n, (i) => i);
    }

    List<int> sampled = [];
    sampled.add(0); // First point

    double every = (n - 2) / (threshold - 2).toDouble();

    for (int i = 1; i < threshold - 1; i++) {
      int pointIndexFrom = ((i - 1) * every).floor() + 1;
      int pointIndexTo = (i * every).floor() + 1;
      pointIndexTo = math.min(pointIndexTo, n - 1);

      // Next bucket average
      int nextBucketStart = (i * every).floor() + 1;
      int nextBucketEnd = ((i + 1) * every).floor() + 1;
      nextBucketEnd = math.min(nextBucketEnd, n);

      double avgX = 0.0;
      double avgY = 0.0;
      int nextBucketSize = nextBucketEnd - nextBucketStart;
      if (nextBucketSize > 0) {
        for (int j = nextBucketStart; j < nextBucketEnd; j++) {
          avgX += xs[j];
          avgY += ys[j];
        }
        avgX /= nextBucketSize;
        avgY /= nextBucketSize;
      } else {
        avgX = xs[n - 1];
        avgY = ys[n - 1];
      }

      // Previous point (a)
      double aX = xs[sampled.last];
      double aY = ys[sampled.last];

      double maxArea = -1.0;
      int selectedIndex = pointIndexFrom;

      for (int j = pointIndexFrom; j < pointIndexTo; j++) {
        double cX = xs[j];
        double cY = ys[j];
        double bX = avgX;
        double bY = avgY;

        double area = (aX * (cY - bY) + cX * (bY - aY) + bX * (aY - cY)).abs() / 2.0;

        if (area > maxArea) {
          maxArea = area;
          selectedIndex = j;
        }
      }

      sampled.add(selectedIndex);
    }

    sampled.add(n - 1); // Last point

    return sampled;
  }
}

