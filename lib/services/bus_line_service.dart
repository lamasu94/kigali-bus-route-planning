import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_line.dart';

class BusLineService {
  final CollectionReference<Map<String, dynamic>> busLines =
  FirebaseFirestore.instance.collection('busLines');

  // Add a new bus line
  Future<void> addBusLine(BusLine line) async {
    await busLines.add(line.toMap());
  }

  // Get all bus lines
  Stream<List<BusLine>> getBusLines() {
    return busLines.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BusLine.fromDoc(doc);
      }).toList();
    });
  }

  // Get only active bus lines
  Stream<List<BusLine>> getActiveBusLines() {
    return busLines
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BusLine.fromDoc(doc);
      }).toList();
    });
  }
// Update an existing bus line
  Future<void> updateBusLine(BusLine line) async {
    await busLines.doc(line.id).update(line.toMap());
  }

  // Delete a bus line
  Future<void> deleteBusLine(String id) async {
    await busLines.doc(id).delete();
  }
}