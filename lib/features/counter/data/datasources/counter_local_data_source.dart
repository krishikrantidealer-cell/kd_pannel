import '../models/counter_model.dart';

abstract class CounterLocalDataSource {
  Future<CounterModel> getLastCounter();
  Future<void> cacheCounter(CounterModel counterToCache);
}

class CounterLocalDataSourceImpl implements CounterLocalDataSource {
  int _fakeDatabaseValue = 0;

  @override
  Future<CounterModel> getLastCounter() async {
    return CounterModel(value: _fakeDatabaseValue);
  }

  @override
  Future<void> cacheCounter(CounterModel counterToCache) async {
    _fakeDatabaseValue = counterToCache.value;
  }
}
