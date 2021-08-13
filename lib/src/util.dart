import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Fetches user from Firebase and returns a promise
Future<types.User> fetchUser(String? phoneNumber) async {
  var doc =
      await FirebaseFirestore.instance.collection('bijlesgevers').doc(phoneNumber).get();
  if(doc.data() == null){
    doc = await FirebaseFirestore.instance.collection('bijleszoekers').doc(phoneNumber).get();
  }

  return processUserDocument(doc);
}

/// Returns a list of [types.Room] created from Firebase query.
/// If room has 2 participants, sets correct room name and image.
Future<List<types.Room>> processRoomsQuery(
  User firebaseUser,
  QuerySnapshot<Map<String, dynamic>> query,
) async {
  final futures = query.docs.map(
    (doc) => processRoomDocument(doc, firebaseUser),
  );

  return await Future.wait(futures);
}

/// Returns a [types.Room] created from Firebase document
Future<types.Room> processRoomDocument(
  DocumentSnapshot<Map<String, dynamic>> doc,
  User firebaseUser,
) async {
  final createdAt = doc.data()?['createdAt'] as Timestamp?;
  var imageUrl = doc.data()?['imageUrl'] as String?;
  final metadata = doc.data()?['metadata'] as Map<String, dynamic>?;
  var name = doc.data()?['name'] as String?;
  final type = doc.data()!['type'] as String;
  final userIds = doc.data()!['userIds'] as List<dynamic>;
  final userRoles = doc.data()?['userRoles'] as Map<String, dynamic>?;


  final users = await Future.wait(
    userIds.map(
      (userId) => fetchUser(
        userId as String,
        //role: types.getRoleFromString(userRoles?[userId] as String?),
      ),
    ),
  );

  if (type == types.RoomType.direct.toShortString()) {
    try {
      final otherUser = users.firstWhere(
        (u) => u.id != firebaseUser.uid,
      );

      imageUrl = otherUser.fotoUrl;
      name = otherUser.naam;
    } catch (e) {
      // Do nothing if other user is not found, because he should be found.
      // Consider falling back to some default values.
    }
  }

  final room = types.Room(
    createdAt: DateTime.now(),
    id: doc.id,
    imageUrl: imageUrl,
    metadata: metadata,
    name: name,
    type: types.getRoomTypeFromString(type),
    users: users,
  );

  return room;
}

/// Returns a [types.User] created from Firebase document
types.User processUserDocument(
  DocumentSnapshot<Map<String, dynamic>> doc) {
  final createdAt = doc.data()?['createdAt'] as Timestamp?;
  final naam = doc.data()?['naam'] as String?;
  final imageUrl = doc.data()?['imageUrl'] as String?;
  final leeftijd = doc.data()?['leeftijd'] as int?;
  final telefoonnummer = doc.data()?['telefoonnummer'] as String?;
  final laatstGezien = doc.data()?['laatstGezien'] as Timestamp?;
  final metadata = doc.data()?['metadata'] as Map<String, dynamic>?;


  final user = types.User(
    aangemaaktOp: DateTime.now(),
    naam: naam,
    leeftijd: leeftijd,
    telefoonnummer: telefoonnummer,
    id: doc.id,
    fotoUrl: imageUrl,
    laatstGezien: DateTime.now(),
    metadata: metadata,
  );

  return user;
}
