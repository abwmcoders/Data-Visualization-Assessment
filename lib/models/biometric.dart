import 'package:intl/intl.dart';

class Biometric {
  final DateTime date;
  final double? hrv;
  final int? rhr;
  final int? steps;
  final int? sleepScore;

  Biometric({required this.date, this.hrv, this.rhr, this.steps, this.sleepScore});

  factory Biometric.fromJson(Map<String, dynamic> json) {
    return Biometric(
      date: DateFormat('yyyy-MM-dd').parse(json['date']),
      hrv: json['hrv']?.toDouble(),
      rhr: json['rhr'],
      steps: json['steps'],
      sleepScore: json['sleepScore'],
    );
  }
}

class Journal {
  final DateTime date;
  final int mood;
  final String note;

  Journal({required this.date, required this.mood, required this.note});

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(date: DateFormat('yyyy-MM-dd').parse(json['date']), mood: json['mood'], note: json['note']);
  }
}

