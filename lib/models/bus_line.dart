import 'package:cloud_firestore/cloud_firestore.dart';

class BusLine {
  BusLine({
    this.id = '',
    required this.busNumber,
    required this.routeName,
    required this.stops,
    this.isActive = true,
  });

  final String id;
  final String busNumber;
  final String routeName;
  final List<String> stops;
  final bool isActive;

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'routeName': routeName,
      'stops': stops,
      'isActive': isActive,
    };
  }

  factory BusLine.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data()!;

    return BusLine(
      id: doc.id,
      busNumber: data['busNumber'] as String,
      routeName: data['routeName'] as String,
      stops: List<String>.from(data['stops']),
      isActive: data['isActive'] as bool,
    );
  }
}