import '../../domain/entities/counter.dart';

class CounterModel extends Counter {
  const CounterModel({required super.value});

  factory CounterModel.fromJson(Map<String, dynamic> json) {
    return CounterModel(value: json['value']);
  }

  Map<String, dynamic> toJson() {
    return {'value': value};
  }
}
