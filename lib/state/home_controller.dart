import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bus_line.dart';
import '../repositories/bus_line_service.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._busLineService) {
    _listenToBusLines();
  }

  final BusLineService _busLineService;
  StreamSubscription<List<BusLine>>? _subscription;

  // Private data (ALL of this user's lines, active and inactive)
  List<BusLine> _busLines = [];
  bool _isLoading = true;
  Object? _error;

  String? _fromStop;
  String? _toStop;

  List<BusLine> _matchingRoutes = [];
  bool _hasSearched = false;

  // The chosen filter lives here: 'all', 'active' or 'inactive'.
  String _filter = 'all';

  // Getters
  List<BusLine> get busLines => List.unmodifiable(_busLines);
  bool get isLoading => _isLoading;
  Object? get error => _error;

  String? get fromStop => _fromStop;
  String? get toStop => _toStop;

  List<BusLine> get matchingRoutes => List.unmodifiable(_matchingRoutes);
  bool get hasSearched => _hasSearched;

  String get filter => _filter;

  // Computed, never stored: the lines the chips currently show.
  List<BusLine> get visible {
    if (_filter == 'active') return _busLines.where((l) => l.isActive).toList();
    if (_filter == 'inactive') {
      return _busLines.where((l) => !l.isActive).toList();
    }
    return _busLines;
  }

  // Only active lines are used for route search and stops.
  List<BusLine> get _activeLines =>
      _busLines.where((l) => l.isActive).toList();

  // Number of active bus lines (shown on the form screen).
  int get activeCount => _activeLines.length;

  // Unique, sorted stop names from all active bus lines.
  List<String> get stops {
    final result = <String>{};
    for (final line in _activeLines) {
      result.addAll(line.stops);
    }
    return result.toList()..sort();
  }

  // Listen to the Firestore stream (all of this user's lines).
  void _listenToBusLines() {
    _subscription = _busLineService.getBusLines().listen(
          (lines) {
        _busLines = lines;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void setFilter(String value) {
    _filter = value;
    notifyListeners();
  }

  void setFromStop(String? value) {
    _fromStop = value;
    _hasSearched = false;
    notifyListeners();
  }

  void setToStop(String? value) {
    _toStop = value;
    _hasSearched = false;
    notifyListeners();
  }

  // Used by the "Popular stops" chips.
  void selectStop(String stop) {
    if (_fromStop == null) {
      _fromStop = stop;
    } else {
      _toStop = stop;
    }
    _hasSearched = false;
    notifyListeners();
  }

  void clearSelection() {
    _fromStop = null;
    _toStop = null;
    _matchingRoutes = [];
    _hasSearched = false;
    notifyListeners();
  }

  // Returns an error message if the search is invalid, otherwise null.
  String? findRoute() {
    if (_fromStop == null || _toStop == null) {
      return 'Please select both your starting point and destination.';
    }

    if (_fromStop == _toStop) {
      return 'Your starting point and destination must be different.';
    }

    final from = _fromStop!.toLowerCase();
    final to = _toStop!.toLowerCase();

    _matchingRoutes = _activeLines.where((line) {
      final fromIndex =
      line.stops.indexWhere((stop) => stop.toLowerCase() == from);
      final toIndex =
      line.stops.indexWhere((stop) => stop.toLowerCase() == to);

      return fromIndex != -1 && toIndex != -1 && fromIndex < toIndex;
    }).toList();

    _hasSearched = true;
    notifyListeners();
    return null;
  }

  // The stream from Firestore delivers the new line, so no notify is needed.
  Future<void> addBusLine(BusLine line) async {
    await _busLineService.addBusLine(line);
  }

  Future<void> updateBusLine(BusLine line) async {
    await _busLineService.updateBusLine(line);
    _hasSearched = false;
    notifyListeners();
  }

  Future<void> deleteBusLine(BusLine line) async {
    await _busLineService.deleteBusLine(line.id);
    _matchingRoutes.removeWhere((route) => route.id == line.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}