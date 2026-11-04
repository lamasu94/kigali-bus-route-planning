import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../state/home_controller.dart';
import 'bus_line_form.dart';
import '../models/bus_line.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const primaryColor = Color(0xFF1264E8);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Open the form and hand it the SAME brain.
  void _openForm(BuildContext context) {
    final controller = context.read<HomeController>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<HomeController>.value(
          value: controller,
          child: const BusLineForm(),
        ),
      ),
    );
  }

  void _onFindRoute() {
    final error = context.read<HomeController>().findRoute();
    if (error != null) _showMessage(error);
  }

  // Edit an existing bus line.
  Future<void> _editBusLine(BusLine line) async {
    final controller = context.read<HomeController>(); // read BEFORE the await
    final busNumberController = TextEditingController(text: line.busNumber);
    final routeNameController = TextEditingController(text: line.routeName);
    final stopsController = TextEditingController(text: line.stops.join(', '));

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
                        decoration:
                        const InputDecoration(labelText: 'Bus number'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: routeNameController,
                        decoration:
                        const InputDecoration(labelText: 'Route name'),
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
                          // Local dialog state only.
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
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
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
        _showMessage('Please complete all bus line fields.');
        return;
      }

      final updatedLine = BusLine(
        id: line.id,
        busNumber: busNumberController.text.trim(),
        routeName: routeNameController.text.trim(),
        stops: updatedStops,
        isActive: isActive,
      );

      await controller.updateBusLine(updatedLine);

      if (!mounted) return;
      _showMessage('Bus line updated successfully!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error updating bus line: $e');
    } finally {
      busNumberController.dispose();
      routeNameController.dispose();
      stopsController.dispose();
    }
  }

  // Delete a bus line after confirmation.
  Future<void> _deleteBusLine(BusLine line) async {
    final controller = context.read<HomeController>(); // read BEFORE the await
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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
      await controller.deleteBusLine(line);

      if (!mounted) return;
      _showMessage('Bus line deleted successfully!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error deleting bus line: $e');
    }
  }

  // Logout from Firebase.
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Logout failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Finds the brain above and subscribes: every notifyListeners() rebuilds.
    final controller = context.watch<HomeController>();

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
      body: SafeArea(child: _body(context, controller)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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
  }

  Widget _body(BuildContext context, HomeController controller) {
    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load bus routes.\n${controller.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stops = controller.stops;
    final visible = controller.visible; // filtered list for the chips

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
                colors: [Color(0xFF1264E8), Color(0xFF4389F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 32),
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
              border: Border.all(color: const Color(0xFFE6EAF0)),
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
                  value: controller.fromStop,
                  stops: stops,
                  icon: Icons.radio_button_checked,
                  iconColor: const Color(0xFF16A36A),
                  onChanged: controller.setFromStop,
                ),
                const SizedBox(height: 18),
                _buildStopDropdown(
                  label: 'Destination',
                  hint: 'Select your destination',
                  value: controller.toStop,
                  stops: stops,
                  icon: Icons.location_on,
                  iconColor: const Color(0xFFE64C60),
                  onChanged: controller.setToStop,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: stops.isEmpty ? null : _onFindRoute,
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
                    style: TextStyle(color: Color(0xFF65738A), fontSize: 13),
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
                onPressed: controller.clearSelection,
                child: const Text('Clear'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (stops.isEmpty)
            const Text(
              'Stops will appear here when bus lines are added.',
              style: TextStyle(color: Color(0xFF65738A)),
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
                  side: const BorderSide(color: Color(0xFFE0E6EF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () => controller.selectStop(stop),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Route results
          if (controller.hasSearched) ...[
            const Text(
              'Available bus routes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF17243B),
              ),
            ),
            const SizedBox(height: 12),
            if (controller.matchingRoutes.isEmpty)
              _buildNoRouteCard()
            else
              ...controller.matchingRoutes
                  .map((line) => _buildRouteCard(controller, line)),
            const SizedBox(height: 24),
          ],

          // ---- NEW: Your bus lines with ALL / ACTIVE / INACTIVE chips ----
          const Text(
            'Your bus lines',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17243B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['all', 'active', 'inactive']
                .map((f) => ChoiceChip(
              label: Text(f.toUpperCase()),
              selected: controller.filter == f,
              onSelected: (_) =>
                  context.read<HomeController>().setFilter(f),
            ))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (controller.busLines.isEmpty)
            _buildEmptyCard('No bus lines yet. Tap + to add one.')
          else if (visible.isEmpty)
            _buildEmptyCard('Nothing matches this filter.')
          else
            ...visible.map(_buildLineTile),

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
                Icon(Icons.lightbulb_outline, color: primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New to Kigali? Select your starting stop and destination to find an available bus route.',
                    style: TextStyle(height: 1.5, color: Color(0xFF263B59)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: message card for the two kinds of "empty".
  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF65738A)),
      ),
    );
  }

  // NEW: one row in the "Your bus lines" list.
  Widget _buildLineTile(BusLine line) {
    final color =
    line.isActive ? const Color(0xFF16A36A) : const Color(0xFF8995A7);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus ${line.busNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  line.routeName,
                  style: const TextStyle(color: Color(0xFF65738A)),
                ),
                Text(
                  '${line.stops.length} stops · '
                      '${line.isActive ? 'Active' : 'Inactive'}',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editBusLine(line);
              } else if (value == 'delete') {
                _deleteBusLine(line);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoRouteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'There is currently no active bus line serving both stops in this direction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF65738A), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(HomeController controller, BusLine line) {
    final from = controller.fromStop!.toLowerCase();
    final to = controller.toStop!.toLowerCase();

    final fromIndex =
    line.stops.indexWhere((stop) => stop.toLowerCase() == from);
    final toIndex = line.stops.indexWhere((stop) => stop.toLowerCase() == to);

    final journeyStops = line.stops.sublist(fromIndex, toIndex + 1);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE5F3)),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: const TextStyle(color: Color(0xFF65738A)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Color(0xFF16A36A)),

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
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 19),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.red)),
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
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ...journeyStops.asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            final isFirst = index == 0;
            final isLast = index == journeyStops.length - 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                      padding: EdgeInsets.only(left: 8),
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
                      padding: EdgeInsets.only(left: 8),
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF65738A)),
          ),
        ],
      ),
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
          child: Icon(icon, color: iconColor, size: 21),
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
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF65738A)),
          ),
        ],
      ),
    );
  }
}