import '../entities/counter.dart';

abstract class CounterRepository {
  Future<Counter> getCounter();
  Future<Counter> incrementCounter(int currentValue);
}
