
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/bus_line.dart';
import 'services/bus_line_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BusLineService _busLineService = BusLineService();

  String? _fromStop;
  String? _toStop;

  List<BusLine> _matchingRoutes = [];
  bool _hasSearched = false;

  static const primaryColor = Color(0xFF1264E8);

  // Find bus lines that serve both stops in the correct order.
  void _findRoute(List<BusLine> busLines) {
    if (_fromStop == null || _toStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both your starting point and destination.',
          ),
        ),
      );
      return;
    }

    if (_fromStop == _toStop) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your starting point and destination must be different.',
          ),
        ),
      );
      return;
    }

    final matchingRoutes = busLines.where((line) {
      final fromIndex = line.stops.indexWhere(
            (stop) => stop.toLowerCase() == _fromStop!.toLowerCase(),
      );

      final toIndex = line.stops.indexWhere(
            (stop) => stop.toLowerCase() == _toStop!.toLowerCase(),
      );

      return fromIndex != -1 &&
          toIndex != -1 &&
          fromIndex < toIndex;
    }).toList();

    setState(() {
      _matchingRoutes = matchingRoutes;
      _hasSearched = true;
    });
  }

  // Get unique stop names from all active bus lines.
  List<String> _getStops(List<BusLine> busLines) {
    final stops = <String>{};

    for (final line in busLines) {
      stops.addAll(line.stops);
    }

    final result = stops.toList();
    result.sort();

    return result;
  }

  // Edit an existing bus line.
  Future<void> _editBusLine(BusLine line) async {
    final busNumberController =
    TextEditingController(text: line.busNumber);
    final routeNameController =
    TextEditingController(text: line.routeName);
    final stopsController =
    TextEditingController(text: line.stops.join(', '));

    bool isActive = line.isActive;

    try {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit bus line'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: busNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Bus number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: routeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Route name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stopsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Stops',
                          hintText: 'Separate stops with commas',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active bus line'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Save changes'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (shouldUpdate != true) return;

      final updatedStops = stopsController.text
          .split(',')
          .map((stop) => stop.trim())
          .where((stop) => stop.isNotEmpty)
          .toList();

      if (busNumberController.text.trim().isEmpty ||
          routeNameController.text.trim().isEmpty ||
          updatedStops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete all bus line fields.'),
          ),
        );
        return;
      }

      final updatedLine = BusLine(
        id: line.id,
        busNumber: busNumberController.text.trim(),
        routeName: routeNameController.text.trim(),
        stops: updatedStops,
        isActive: isActive,
      );

      await _busLineService.updateBusLine(updatedLine);

      if (!mounted) return;

      setState(() {
        _hasSearched = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus line updated successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating bus line: $e')),
      );
    } finally {
      busNumberController.dispose();
      routeNameController.dispose();
      stopsController.dispose();
    }
  }

  // Delete a bus line after confirmation.
  Future<void> _deleteBusLine(BusLine line) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete bus line?'),
          content: Text(
            'Are you sure you want to delete bus ${line.busNumber} '
                '(${line.routeName})?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _busLineService.deleteBusLine(line.id);

      if (!mounted) return;

      setState(() {
        _matchingRoutes.removeWhere(
              (route) => route.id == line.id,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus line deleted successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bus line: $e')),
      );
    }
  }

  // Logout from Firebase.
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusLine>>(
      stream: _busLineService.getActiveBusLines(),
      builder: (context, snapshot) {
        final busLines = snapshot.data ?? [];
        final stops = _getStops(busLines);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),

          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF17243B),
            elevation: 0,
            title: const Row(
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  color: primaryColor,
                  size: 30,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kigali Bus Planner',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _logout,
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),

          body: SafeArea(
            child: Builder(
              builder: (context) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load bus routes.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1264E8),
                              Color(0xFF4389F5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Where are you going?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Find the right bus and travel across Kigali with confidence.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Route search card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE6EAF0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PLAN YOUR JOURNEY',
                              style: TextStyle(
                                color: Color(0xFF65738A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),

                            const SizedBox(height: 20),

                            _buildStopDropdown(
                              label: 'Starting point',
                              hint: 'Select your starting stop',
                              value: _fromStop,
                              stops: stops,
                              icon: Icons.radio_button_checked,
                              iconColor: const Color(0xFF16A36A),
                              onChanged: (value) {
                                setState(() {
                                  _fromStop = value;
                                  _hasSearched = false;
                                });
                              },
                            ),

                            const SizedBox(height: 18),

                            _buildStopDropdown(
                              label: 'Destination',
                              hint: 'Select your destination',
                              value: _toStop,
                              stops: stops,
                              icon: Icons.location_on,
                              iconColor: const Color(0xFFE64C60),
                              onChanged: (value) {
                                setState(() {
                                  _toStop = value;
                                  _hasSearched = false;
                                });
                              },
                            ),

                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: stops.isEmpty
                                    ? null
                                    : () => _findRoute(busLines),
                                icon: const Icon(Icons.search_rounded),
                                label: const Text(
                                  'Find my bus route',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),

                            if (stops.isEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'No stops have been added to Firestore yet.',
                                style: TextStyle(
                                  color: Color(0xFF65738A),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Popular stops
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Popular stops',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF17243B),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _fromStop = null;
                                _toStop = null;
                                _matchingRoutes = [];
                                _hasSearched = false;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (stops.isEmpty)
                        const Text(
                          'Stops will appear here when bus lines are added.',
                          style: TextStyle(
                            color: Color(0xFF65738A),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 9,
                          runSpacing: 10,
                          children: stops.map((stop) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.place_outlined,
                                size: 17,
                                color: primaryColor,
                              ),
                              label: Text(stop),
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFFE0E6EF),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_fromStop == null) {
                                    _fromStop = stop;
                                  } else {
                                    _toStop = stop;
                                  }
                                  _hasSearched = false;
                                });
                              },
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 24),

                      // Route results
                      if (_hasSearched) ...[
                        const Text(
                          'Available bus routes',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF17243B),
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (_matchingRoutes.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE6EAF0),
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.directions_bus_outlined,
                                  size: 35,
                                  color: Color(0xFF8995A7),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No direct bus route found.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'There is currently no active bus line serving both stops in this direction.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF65738A),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._matchingRoutes.map((line) {
                            final fromIndex = line.stops.indexWhere(
                                  (stop) =>
                              stop.toLowerCase() ==
                                  _fromStop!.toLowerCase(),
                            );

                            final toIndex = line.stops.indexWhere(
                                  (stop) =>
                              stop.toLowerCase() ==
                                  _toStop!.toLowerCase(),
                            );

                            final journeyStops =
                            line.stops.sublist(fromIndex, toIndex + 1);

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFDCE5F3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7F1FF),
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.directions_bus_rounded,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Bus ${line.busNumber}',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              line.routeName,
                                              style: const TextStyle(
                                                color: Color(0xFF65738A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF16A36A),
                                      ),

                                      // Edit and Delete menu
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editBusLine(line);
                                          } else if (value == 'delete') {
                                            _deleteBusLine(line);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 19,
                                                ),
                                                SizedBox(width: 10),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 19,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 26),

                                  const Text(
                                    'Your stops',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  ...journeyStops.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final stop = entry.value;
                                    final isFirst = index == 0;
                                    final isLast =
                                        index == journeyStops.length - 1;

                                    return Padding(
                                      padding:
                                      const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isFirst
                                                ? Icons.radio_button_checked
                                                : isLast
                                                ? Icons.location_on
                                                : Icons.circle,
                                            size: isFirst || isLast ? 19 : 9,
                                            color: isFirst
                                                ? const Color(0xFF16A36A)
                                                : isLast
                                                ? const Color(0xFFE64C60)
                                                : const Color(0xFF8995A7),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            stop,
                                            style: TextStyle(
                                              fontWeight: isFirst || isLast
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (isFirst)
                                            const Padding(
                                              padding:
                                              EdgeInsets.only(left: 8),
                                              child: Text(
                                                'Start',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF16A36A),
                                                ),
                                              ),
                                            ),
                                          if (isLast)
                                            const Padding(
                                              padding:
                                              EdgeInsets.only(left: 8),
                                              child: Text(
                                                'Destination',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFE64C60),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),

                                  Text(
                                    '${journeyStops.length - 1} stop(s) between your journey endpoints',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF65738A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],

                      const SizedBox(height: 24),

                      // Extra features
                      const Text(
                        'Your journeys',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17243B),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.favorite_outline,
                              title: 'Favourites',
                              subtitle: 'Saved journeys',
                              color: const Color(0xFFE84D75),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.report_problem_outlined,
                              title: 'Report issue',
                              subtitle: 'Bus problems',
                              color: const Color(0xFFE69B25),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Helpful note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F1FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: primaryColor,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'New to Kigali? Select your starting stop and destination to find an available bus route.',
                                style: TextStyle(
                                  height: 1.5,
                                  color: Color(0xFF263B59),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom navigation
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: primaryColor,
            unselectedItemColor: const Color(0xFF8995A7),
            backgroundColor: Colors.white,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                label: 'Routes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline),
                label: 'Favourites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  // Reusable stop dropdown.
  Widget _buildStopDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> stops,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = stops.contains(value) ? value : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Icon(
            icon,
            color: iconColor,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF65738A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                value: validValue,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1264E8),
                      width: 1.5,
                    ),
                  ),
                ),
                items: stops.map((stop) {
                  return DropdownMenuItem<String>(
                    value: stop,
                    child: Text(stop),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Reusable feature card.
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE6EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF65738A),
            ),
          ),
        ],
      ),
    );
  }
}
