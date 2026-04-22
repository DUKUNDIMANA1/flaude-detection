// lib/ml/model_loader.dart
import 'ml_engine.dart';

class ModelLoader {
  static final ModelLoader _instance = ModelLoader._internal();
  factory ModelLoader() => _instance;
  ModelLoader._internal();

  final MLEngine _engine = MLEngine();
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    await _engine.loadModel();
    _loaded = true;
  }

  MLEngine get engine => _engine;
  bool get isLoaded => _loaded;
}
