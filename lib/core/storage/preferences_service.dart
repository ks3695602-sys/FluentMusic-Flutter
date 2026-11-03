import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // Liquid Glass Studio Parameters
  double _blurRadius = 24.0;
  double _refractionIndex = 1.15;
  double _tintOpacity = 0.25;
  bool _enableChromaticAberration = true;
  bool _enableMeshBackground = true;

  // Audio & Settings
  String _audioQuality = 'High (160k Opus)';
  String _lastFmUsername = '';
  bool _scrobblingEnabled = false;

  double get blurRadius => _blurRadius;
  double get refractionIndex => _refractionIndex;
  double get tintOpacity => _tintOpacity;
  bool get enableChromaticAberration => _enableChromaticAberration;
  bool get enableMeshBackground => _enableMeshBackground;

  String get audioQuality => _audioQuality;
  String get lastFmUsername => _lastFmUsername;
  bool get scrobblingEnabled => _scrobblingEnabled;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _blurRadius = _prefs?.getDouble('blurRadius') ?? 24.0;
    _refractionIndex = _prefs?.getDouble('refractionIndex') ?? 1.15;
    _tintOpacity = _prefs?.getDouble('tintOpacity') ?? 0.25;
    _enableChromaticAberration = _prefs?.getBool('enableChromaticAberration') ?? true;
    _enableMeshBackground = _prefs?.getBool('enableMeshBackground') ?? true;

    _audioQuality = _prefs?.getString('audioQuality') ?? 'High (160k Opus)';
    _lastFmUsername = _prefs?.getString('lastFmUsername') ?? '';
    _scrobblingEnabled = _prefs?.getBool('scrobblingEnabled') ?? false;
    notifyListeners();
  }

  Future<void> setBlurRadius(double value) async {
    _blurRadius = value;
    await _prefs?.setDouble('blurRadius', value);
    notifyListeners();
  }

  Future<void> setRefractionIndex(double value) async {
    _refractionIndex = value;
    await _prefs?.setDouble('refractionIndex', value);
    notifyListeners();
  }

  Future<void> setTintOpacity(double value) async {
    _tintOpacity = value;
    await _prefs?.setDouble('tintOpacity', value);
    notifyListeners();
  }

  Future<void> setChromaticAberration(bool value) async {
    _enableChromaticAberration = value;
    await _prefs?.setBool('enableChromaticAberration', value);
    notifyListeners();
  }

  Future<void> setMeshBackground(bool value) async {
    _enableMeshBackground = value;
    await _prefs?.setBool('enableMeshBackground', value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    await _prefs?.setString('audioQuality', value);
    notifyListeners();
  }

  Future<void> setLastFmUsername(String value) async {
    _lastFmUsername = value;
    await _prefs?.setString('lastFmUsername', value);
    notifyListeners();
  }

  Future<void> setScrobblingEnabled(bool value) async {
    _scrobblingEnabled = value;
    await _prefs?.setBool('scrobblingEnabled', value);
    notifyListeners();
  }
}
