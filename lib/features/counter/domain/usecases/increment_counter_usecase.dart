import '../entities/counter.dart';
import '../repositories/counter_repository.dart';

class IncrementCounterUseCase {
  final CounterRepository repository;

  IncrementCounterUseCase(this.repository);

  Future<Counter> execute(int currentValue) async {
    return await repository.incrementCounter(currentValue);
  }
}
