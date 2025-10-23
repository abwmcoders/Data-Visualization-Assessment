import 'package:flutter/material.dart';
import '../models/biometric.dart';
import '../services/data_service.dart';

class BiometricsViewModel extends ChangeNotifier {
  final DataService _service = DataService();
  List<Biometric> biometrics = [];
  List<Journal> journals = [];
  bool isLoading = false;
  String? error;
  int rangeDays = 90;
  bool largeDataset = false;
  DateTime? selectedDate;

  BiometricsViewModel() {
    loadData(); 
  }

  Future<void> loadData() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      biometrics = await _service.loadBiometrics();
      journals = await _service.loadJournals();
      if (largeDataset) biometrics = _service.generateLargeDataset(biometrics, 10000);
      // Sort and handle missing data (e.g., fill gaps)
      biometrics.sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void setRange(int days) {
    rangeDays = days;
    notifyListeners();
  }

  void toggleLargeDataset(bool value) {
    largeDataset = value;
    loadData();
  }

  void setSelectedDate(DateTime? date) {
    selectedDate = date;
    notifyListeners();
  }

  // List<Biometric> getFilteredData() {
  //   DateTime end = DateTime.now();
  //   DateTime start = end.subtract(Duration(days: rangeDays));
  //   var filtered = biometrics
  //       .where((b) => b.date.isAfter(start) && b.date.isBefore(end.add(Duration(days: 1))))
  //       .toList();
  //   if (rangeDays > 7 && filtered.length > 200) {
  //     return _service.decimate(filtered, 200);
  //   }
  //   return filtered;
  // }

  List<Biometric> getFilteredData() {
    DateTime end = DateTime.now();
    DateTime start = end.subtract(Duration(days: rangeDays));
    var filtered = biometrics
        .where((b) => !b.date.isBefore(start) && b.date.isBefore(end.add(Duration(days: 1))))
        .toList();
    if (rangeDays > 7 && filtered.length > 200) {
      return _service.decimate(filtered, 200);
    }
    return filtered;
  }
}

