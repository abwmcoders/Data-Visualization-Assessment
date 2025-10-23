import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/biometric.dart';

class DataService {
  Future<List<Biometric>> loadBiometrics() async {
    await Future.delayed(Duration(milliseconds: Random().nextInt(501) + 700));
    if (Random().nextDouble() < 0.1) throw Exception('Failed to load biometrics');
    final String response = await rootBundle.loadString('assets/biometrics_90d.json');
    final List<dynamic> data = json.decode(response);
    return data.map((json) => Biometric.fromJson(json)).toList();
  }

  Future<List<Journal>> loadJournals() async {
    await Future.delayed(Duration(milliseconds: Random().nextInt(501) + 700));
    if (Random().nextDouble() < 0.1) throw Exception('Failed to load journals');
    final String response = await rootBundle.loadString('assets/journals.json');
    final List<dynamic> data = json.decode(response);
    return data.map((json) => Journal.fromJson(json)).toList();
  }

  // LTTB Decimation Implementation
  List<Biometric> decimate(List<Biometric> data, int targetSize) {
    if (data.length <= targetSize) return data;
    // Simplified LTTB: divide into buckets, select point with largest triangle area
    List<Biometric> decimated = [data.first];
    double bucketSize = (data.length - 2) / (targetSize - 2);
    for (int i = 1; i < targetSize - 1; i++) {
      int start = ((i - 1) * bucketSize).floor() + 1;
      int end = (i * bucketSize).floor() + 1;
      // Find point with max area (placeholder: average for simplicity; extend for full LTTB)
      double avgHrv = 0;
      int count = 0;
      for (int j = start; j < end; j++) {
        if (data[j].hrv != null) {
          avgHrv += data[j].hrv!;
          count++;
        }
      }
      avgHrv /= count;
      decimated.add(Biometric(date: data[start].date, hrv: avgHrv)); // Extend for other fields
    }
    decimated.add(data.last);
    return decimated;
  }

  // Calculate rolling mean and std for bands
  List<Map<String, double?>> calculateBands(List<Biometric> data) {
    List<Map<String, double?>> bands = [];
    for (int i = 6; i < data.length; i++) {
      // 7-day window
      List<double> window = data.sublist(i - 6, i + 1).map((b) => b.hrv ?? 0).toList();
      double mean = window.reduce((a, b) => a + b) / 7;
      double std = sqrt(window.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / 7);
      bands.add({'date': data[i].date.millisecondsSinceEpoch.toDouble(), 'low': mean - std, 'high': mean + std});
    }
    return bands;
  }

  // Generate large dataset
  List<Biometric> generateLargeDataset(List<Biometric> base, int size) {
    List<Biometric> large = [];
    for (int i = 0; i < size; i++) {
      var ref = base[i % base.length];
      large.add(
        Biometric(
          date: ref.date.add(Duration(days: i)),
          hrv: ref.hrv! + Random().nextDouble() * 10 - 5,
          rhr: ref.rhr! + Random().nextInt(5) - 2,
          steps: ref.steps! + Random().nextInt(1000) - 500,
        ),
      );
    }
    return large;
  }
}
