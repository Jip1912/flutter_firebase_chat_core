import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Fetches user from Firebase and returns a promise
Future<types.User> fetchUser(String? phoneNumber) async {
  var doc = await FirebaseFirestore.instance
      .collection('bijlesgevers')
      .doc(phoneNumber)
      .get();
  if (doc.data() == null) {
    doc = await FirebaseFirestore.instance
        .collection('bijleszoekers')
        .doc(phoneNumber)
        .get();
  }
  return processUserDocument(doc);
}

Future<types.Bijlesgever> fetchBijlesgever(String? phoneNumber) async {
  final doc = await FirebaseFirestore.instance
      .collection('bijlesgevers')
      .doc(phoneNumber)
      .get();
  return processBijlesgeverDocument(doc);
}

Future<types.Bijleszoeker> fetchBijleszoeker(String? phoneNumber) async {
  final doc = await FirebaseFirestore.instance
      .collection('bijleszoekers')
      .doc(phoneNumber)
      .get();
  return processBijleszoekerDocument(doc);
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
  final userPhoneNumbers = doc.data()?['userPhoneNumbers'] as List<dynamic>;
  final userRoles = doc.data()?['userRoles'] as Map<String, dynamic>?;

  final users = await Future.wait(
    userPhoneNumbers.map(
      (userPhoneNumber) => fetchUser(
        userPhoneNumber as String,
        //role: types.getRoleFromString(userRoles?[userId] as String?),
      ),
    ),
  );

  if (type == types.RoomType.direct.toShortString()) {
    try {
      final otherUser =
          users.firstWhere((u) => u.telefoonnummer != firebaseUser.phoneNumber);

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
types.User processUserDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
  final aangemaaktOp = doc.data()?['aangemaaktOp'] as Timestamp?;
  final naam = doc.data()?['naam'] as String?;
  final fotoUrl = doc.data()?['fotoUrl'] as String?;
  final leeftijd = doc.data()?['leeftijd'] as int?;
  final telefoonnummer = doc.data()?['telefoonnummer'] as String?;
  final laatstGezien = doc.data()?['laatstGezien'] as Timestamp?;
  final isBijlesgever = doc.data()?['isBijlesgever'] as bool?;
  final metadata = doc.data()?['metadata'] as Map<String, dynamic>?;
  final fcm = doc.data()?['fcm'] as Map<String, dynamic>;
  final Map<String, DateTime> fcmDoc =
      fcm.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));

  final user = types.User(
      aangemaaktOp: aangemaaktOp?.toDate(),
      naam: naam,
      leeftijd: leeftijd,
      telefoonnummer: telefoonnummer,
      id: doc.id,
      fotoUrl: fotoUrl,
      fcm: fcmDoc,
      laatstGezien: laatstGezien?.toDate(),
      isBijlesgever: isBijlesgever,
      metadata: metadata);

  return user;
}

/// Returns a [types.User] created from Firebase document
types.Bijlesgever processBijlesgeverDocument(
    DocumentSnapshot<Map<String, dynamic>> doc) {
  final aangemaaktOp = doc.data()?['aangemaaktOp'] as Timestamp?;
  final naam = doc.data()?['naam'] as String?;
  final fotoUrl = doc.data()?['fotoUrl'] as String?;
  final leeftijd = doc.data()?['leeftijd'] as int?;
  final telefoonnummer = doc.data()?['telefoonnummer'] as String?;
  final laatstGezien = doc.data()?['laatstGezien'] as Timestamp?;
  final isBijlesgever = doc.data()?['isBijlesgever'] as bool?;
  final metadata = doc.data()?['metadata'] as Map<String, dynamic>?;
  final fcm = doc.data()?['fcm'] as Map<String, dynamic>;
  final Map<String, DateTime> fcmDoc =
      fcm.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
  final vakken =
      (doc.data()?['vakken'] as Iterable<dynamic>?)?.cast<String>().toList();
  final uurloon = doc.data()?['uurloon'] as int?;
  final beschrijving = doc.data()?['beschrijving'] as String;
  final locatie = doc.data()?['locatie'] as dynamic;
  final radius = doc.data()?['radius'] as double?;

  final user = types.Bijlesgever(
      aangemaaktOp: aangemaaktOp?.toDate(),
      naam: naam,
      leeftijd: leeftijd,
      telefoonnummer: telefoonnummer,
      id: doc.id,
      fotoUrl: fotoUrl,
      fcm: fcmDoc,
      laatstGezien: laatstGezien?.toDate(),
      isBijlesgever: isBijlesgever,
      metadata: metadata,
      vakken: vakken,
      uurloon: uurloon,
      beschrijving: beschrijving,
      locatie: locatie,
      radius: radius);

  return user;
}

/// Returns a [types.User] created from Firebase document
types.Bijleszoeker processBijleszoekerDocument(
    DocumentSnapshot<Map<String, dynamic>> doc) {
  final aangemaaktOp = doc.data()?['aangemaaktOp'] as Timestamp?;
  final naam = doc.data()?['naam'] as String?;
  final fotoUrl = doc.data()?['fotoUrl'] as String?;
  final leeftijd = doc.data()?['leeftijd'] as int?;
  final telefoonnummer = doc.data()?['telefoonnummer'] as String?;
  final laatstGezien = doc.data()?['laatstGezien'] as Timestamp?;
  final isBijlesgever = doc.data()?['isBijlesgever'] as bool?;
  final metadata = doc.data()?['metadata'] as Map<String, dynamic>?;
  final fcm = doc.data()?['fcm'] as Map<String, dynamic>;
  final Map<String, DateTime> fcmDoc =
      fcm.map((k, v) => MapEntry(k, (v as Timestamp).toDate()));
  final schoolniveau = doc.data()?['schoolniveau'] as String?;

  final user = types.Bijleszoeker(
      aangemaaktOp: aangemaaktOp?.toDate(),
      naam: naam,
      leeftijd: leeftijd,
      telefoonnummer: telefoonnummer,
      id: doc.id,
      fotoUrl: fotoUrl,
      fcm: fcmDoc,
      laatstGezien: laatstGezien?.toDate(),
      isBijlesgever: isBijlesgever,
      metadata: metadata,
      schoolniveau: schoolniveau);

  return user;
}
