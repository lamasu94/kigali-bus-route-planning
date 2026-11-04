import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_line.dart';

class BusLineService {
  final String uid;

  // Shared top-level collection: busLines/{docId}
  final CollectionReference<Map<String, dynamic>> busLines =
  FirebaseFirestore.instance.collection('busLines');

  BusLineService(this.uid);

  // Add a new bus line, tagged with the owner's uid
  Future<void> addBusLine(BusLine line) async {
    await busLines.add({
      ...line.toMap(),
      'ownerId': uid,
    });
  }

  // Get all of this user's bus lines
  Stream<List<BusLine>> getBusLines() {
    return busLines
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BusLine.fromDoc(doc)).toList();
    });
  }

  // Get only this user's active bus lines
  Stream<List<BusLine>> getActiveBusLines() {
    return busLines
        .where('ownerId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BusLine.fromDoc(doc)).toList();
    });
  }

  // Update an existing bus line (ownerId is left untouched)
  Future<void> updateBusLine(BusLine line) async {
    await busLines.doc(line.id).update(line.toMap());
  }

  // Delete a bus line
  Future<void> deleteBusLine(String id) async {
    await busLines.doc(id).delete();
  }
}