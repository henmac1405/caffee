import 'package:flutter/material.dart';

class ShiftProvider with ChangeNotifier {
  int? _activeShiftId;
  double _modalAwal = 0;
  bool _isShiftOpen = false;

  int? get activeShiftId => _activeShiftId;
  double get modalAwal => _modalAwal;
  bool get isShiftOpen => _isShiftOpen;

  void openShift(int shiftId, double modal) {
    _activeShiftId = shiftId;
    _modalAwal = modal;
    _isShiftOpen = true;
    notifyListeners();
  }

  void closeShift() {
    _activeShiftId = null;
    _modalAwal = 0;
    _isShiftOpen = false;
    notifyListeners();
  }
}
