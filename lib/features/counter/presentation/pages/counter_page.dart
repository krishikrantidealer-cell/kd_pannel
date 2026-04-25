import 'package:flutter/material.dart';
import '../../domain/usecases/increment_counter_usecase.dart';
import '../../domain/entities/counter.dart';

class CounterPage extends StatefulWidget {
  final IncrementCounterUseCase incrementUseCase;

  const CounterPage({super.key, required this.incrementUseCase});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _incrementCounter() async {
    final result = await widget.incrementUseCase.execute(_counter);
    setState(() {
      _counter = result.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Clean Architecture Counter"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
