import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus_line.dart';
import '../state/home_controller.dart';

// Second screen: adds a bus line and shows the live count of active lines.
class BusLineForm extends StatefulWidget {
  const BusLineForm({super.key});

  @override
  State<BusLineForm> createState() => _BusLineFormState();
}

class _BusLineFormState extends State<BusLineForm> {
  final _formKey = GlobalKey<FormState>();
  final _busNumberController = TextEditingController();
  final _routeNameController = TextEditingController();
  final _stopsController = TextEditingController();

  // Ephemeral state: only this form cares about it.
  bool _isActive = true;
  bool _saving = false;

  @override
  void dispose() {
    _busNumberController.dispose();
    _routeNameController.dispose();
    _stopsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Read the brain and the messenger BEFORE the await.
    final controller = context.read<HomeController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final stops = _stopsController.text
        .split(',')
        .map((stop) => stop.trim())
        .where((stop) => stop.isNotEmpty)
        .toList();

    final line = BusLine(
      id: '',
      busNumber: _busNumberController.text.trim(),
      routeName: _routeNameController.text.trim(),
      stops: stops,
      isActive: _isActive,
    );

    setState(() => _saving = true);

    try {
      await controller.addBusLine(line);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Bus line added successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error adding bus line: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // One line: this screen now follows the same brain as the home screen.
    final count = context.watch<HomeController>().activeCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Add bus line')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Active bus lines: $count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _busNumberController,
              decoration: const InputDecoration(labelText: 'Bus number'),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter a bus number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _routeNameController,
              decoration: const InputDecoration(labelText: 'Route name'),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter a route name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stopsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Stops',
                hintText: 'Separate stops with commas',
              ),
              validator: (v) {
                final hasStops = (v ?? '')
                    .split(',')
                    .any((stop) => stop.trim().isNotEmpty);
                return hasStops ? null : 'Enter at least one stop';
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active bus line'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? false),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save bus line'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}