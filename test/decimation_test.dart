import 'package:flutter_test/flutter_test.dart';
import 'package:wearable_device/models/biometric.dart';
import 'package:wearable_device/services/data_service.dart';


void main() {
  test('Decimator preserves min/max and output size', () {
    final service = DataService();
    final data = List.generate(1000, (i) => Biometric(date: DateTime(2025, 1, i + 1), hrv: i.toDouble()));
    final decimated = service.decimate(data, 100);
    expect(decimated.length, 100);
    expect(decimated.first.hrv, data.first.hrv); // Preserves min
    expect(decimated.last.hrv, data.last.hrv); // Preserves max
  });
}
