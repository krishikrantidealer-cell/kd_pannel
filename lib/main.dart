import 'package:flutter/material.dart';
import 'features/counter/data/datasources/counter_local_data_source.dart';
import 'features/counter/data/repositories/counter_repository_impl.dart';
import 'features/counter/domain/usecases/increment_counter_usecase.dart';
import 'features/counter/presentation/pages/counter_page.dart';

void main() {
  // Simple Dependency Injection (Manual)
  // In a real app, use GetIt or a similar Service Locator
  final localDataSource = CounterLocalDataSourceImpl();
  final repository = CounterRepositoryImpl(localDataSource: localDataSource);
  final incrementUseCase = IncrementCounterUseCase(repository);

  runApp(MyApp(incrementUseCase: incrementUseCase));
}

class MyApp extends StatelessWidget {
  final IncrementCounterUseCase incrementUseCase;

  const MyApp({super.key, required this.incrementUseCase});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean Architecture Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: CounterPage(incrementUseCase: incrementUseCase),
    );
  }
}
