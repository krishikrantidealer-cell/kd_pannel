import '../../domain/entities/counter.dart';
import '../../domain/repositories/counter_repository.dart';
import '../datasources/counter_local_data_source.dart';
import '../models/counter_model.dart';

class CounterRepositoryImpl implements CounterRepository {
  final CounterLocalDataSource localDataSource;

  CounterRepositoryImpl({required this.localDataSource});

  @override
  Future<Counter> getCounter() async {
    return await localDataSource.getLastCounter();
  }

  @override
  Future<Counter> incrementCounter(int currentValue) async {
    final newValue = currentValue + 1;
    final model = CounterModel(value: newValue);
    await localDataSource.cacheCounter(model);
    return model;
  }
}
