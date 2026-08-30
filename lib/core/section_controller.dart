/// Tracks the ON/OFF state of each boom section and reports the resulting
/// active boom width. Framework-free (portable to the ESP32 relay driver).
class SectionController {
  final List<bool> _on;

  SectionController(int count) : _on = List<bool>.filled(count, true);

  int get count => _on.length;

  /// Read-only copy of the section states.
  List<bool> get states => List<bool>.unmodifiable(_on);

  bool get anyOn => _on.any((e) => e);

  int get activeCount => _on.where((e) => e).length;

  bool isOn(int index) => _on[index];

  void setOn(int index, bool on) {
    if (index >= 0 && index < _on.length) _on[index] = on;
  }

  void setAll(bool on) {
    for (var i = 0; i < _on.length; i++) {
      _on[i] = on;
    }
  }

  /// Sum of the widths of the sections that are currently ON.
  double activeWidthFt(List<double> sectionWidthsFt) {
    double width = 0;
    for (var i = 0; i < _on.length && i < sectionWidthsFt.length; i++) {
      if (_on[i]) width += sectionWidthsFt[i];
    }
    return width;
  }

  /// Change the number of sections (preserves ON state for surviving ones).
  void resize(int newCount) {
    if (newCount == _on.length) return;
    final current = List<bool>.of(_on);
    _on
      ..clear()
      ..addAll(List<bool>.generate(newCount, (i) => i < current.length ? current[i] : true));
  }
}
