import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'util.dart';

/// Provides access to Firebase chat data. Singleton, use
/// FirebaseChatCore.instance to aceess methods.
class FirebaseChatCore {
  FirebaseChatCore._privateConstructor() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      firebaseUser = user;
    });
  }

  /// Current logged in user in Firebase. Does not update automatically.
  /// Use [FirebaseAuth.authStateChanges] to listen to the state changes.
  User? firebaseUser = FirebaseAuth.instance.currentUser;

  /// Singleton instance
  static final FirebaseChatCore instance =
      FirebaseChatCore._privateConstructor();

  /// Creates a chat group room with [users]. Creator is automatically
  /// added to the group. [name] is required and will be used as
  /// a group name. Add an optional [imageUrl] that will be a group avatar
  /// and [metadata] for any additional custom data.
  Future<types.Room> createGroupRoom({
    String? imageUrl,
    Map<String, dynamic>? metadata,
    required String name,
    required List<types.User> users,
  }) async {
    if (firebaseUser == null) return Future.error('User does not exist');

    final currentUser = await fetchUser(firebaseUser!.uid);
    final roomUsers = [currentUser] + users;

    final room = await FirebaseFirestore.instance.collection('rooms').add({
      'createdAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
      'metadata': metadata,
      'name': name,
      'type': types.RoomType.group.toShortString(),
      'userIds': roomUsers.map((u) => u.id).toList(),
      'userPhoneNumbers': roomUsers.map((u) => u.telefoonnummer).toList()
      // 'userRoles': roomUsers.fold<Map<String, String?>>(
      //   {},
      //   (previousValue, element) => {
      //     ...previousValue,
      //     element.id: element.role?.toShortString(),
      //   },
      // ),
    });

    return types.Room(
      id: room.id,
      imageUrl: imageUrl,
      metadata: metadata,
      name: name,
      type: types.RoomType.group,
      users: roomUsers,
    );
  }

  /// Creates a direct chat for 2 people. Add [metadata] for any additional
  /// custom data.
  Future<types.Room> createRoom(
    types.User otherUser, {
    Map<String, dynamic>? metadata,
  }) async {
    if (firebaseUser == null) return Future.error('User does not exist');

    final query = await FirebaseFirestore.instance
        .collection('rooms')
        .where('userIds', arrayContains: firebaseUser!.uid)
        .get();

    final rooms = await processRoomsQuery(firebaseUser!, query);

    try {
      return rooms.firstWhere((room) {
        if (room.type == types.RoomType.group) return false;

        final userPhoneNumbers = room.users.map((u) => u.telefoonnummer);
        return userPhoneNumbers.contains(firebaseUser!.phoneNumber) &&
            userPhoneNumbers.contains(otherUser.telefoonnummer);
      });
    } catch (e) {
      // Do nothing if room does not exist
      // Create a new room instead
    }

    final currentUser = await fetchUser(firebaseUser!.phoneNumber);
    final users = [currentUser, otherUser];

    final room = await FirebaseFirestore.instance.collection('rooms').add({
      'createdAt': FieldValue.serverTimestamp(),
      'imageUrl': null,
      'metadata': metadata,
      'name': null,
      'users': [
        FirebaseFirestore.instance
            .doc('bijleszoekers/${currentUser.telefoonnummer}'),
        FirebaseFirestore.instance
            .doc('bijlesgevers/${otherUser.telefoonnummer}')
      ],
      'type': types.RoomType.direct.toShortString(),
      'userIds': [firebaseUser!.uid, otherUser.id].toList(),
      'userPhoneNumbers': users.map((u) => u.telefoonnummer).toList(),
      'userRoles': null,
    });

    return types.Room(
      id: room.id,
      metadata: metadata,
      type: types.RoomType.direct,
      users: users,
    );
  }

  /// Creates [types.User] in Firebase to store name and avatar used on
  /// rooms list
  // Future<void> createUserInFirestore(types.User user) async {
  //   await FirebaseFirestore.instance.collection('users').doc(user.id).set({
  //     'id': user.id,
  //     'createdAt': FieldValue.serverTimestamp(),
  //     'firstName': user.firstName,
  //     'imageUrl': user.imageUrl,
  //     'lastName': user.lastName,
  //     'lastSeen': user.lastSeen,
  //     'metadata': user.metadata,
  //     'role': user.role?.toShortString(),
  //   });
  // }

  Future<void> createBijlesGeverInFirestore(
      types.Bijlesgever bijlesgever) async {
    await FirebaseFirestore.instance
        .collection('bijlesgevers')
        .doc(bijlesgever.telefoonnummer)
        .set({
      'aangemaaktOp': bijlesgever.aangemaaktOp,
      'naam': bijlesgever.naam,
      'leeftijd': bijlesgever.leeftijd,
      'id': bijlesgever.id,
      'telefoonnummer': bijlesgever.telefoonnummer,
      'fotoUrl': bijlesgever.fotoUrl,
      'laatstGezien': bijlesgever.laatstGezien,
      'isBijlesgever': bijlesgever.isBijlesgever,
      'fcm': bijlesgever.fcm,
      'vakken': bijlesgever.vakken,
      'uurloon': bijlesgever.uurloon,
      'locatie': bijlesgever.location,
      'radius': bijlesgever.radius,
      'beschrijving': bijlesgever.beschrijving
    });
  }

  Future<void> createBijlesZoekerInFirestore(
      types.Bijleszoeker bijleszoeker) async {
    await FirebaseFirestore.instance
        .collection('bijleszoekers')
        .doc(bijleszoeker.telefoonnummer)
        .set({
      'aangemaaktOp': bijleszoeker.aangemaaktOp,
      'naam': bijleszoeker.naam,
      'leeftijd': bijleszoeker.leeftijd,
      'id': bijleszoeker.id,
      'telefoonnummer': bijleszoeker.telefoonnummer,
      'fotoUrl': bijleszoeker.fotoUrl,
      'laatstGezien': bijleszoeker.laatstGezien,
      'isBijlesgever': bijleszoeker.isBijlesgever,
      'fcm': bijleszoeker.fcm,
      'schoolniveau': bijleszoeker.schoolniveau
    });
  }

  /// Returns a stream of messages from Firebase for a given room
  Stream<List<types.Message>> messages(types.Room room) {
    return FirebaseFirestore.instance
        .collection('rooms/${room.id}/messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs.fold<List<types.Message>>(
          [],
          (previousValue, element) {
            final data = element.data();
            final author = room.users.firstWhere(
              (u) => u.id == data['authorId'],
              orElse: () => types.User(id: data['authorId'] as String),
            );

            data['author'] = author.toJson();
            data['createdAt'] = element['createdAt']?.millisecondsSinceEpoch;
            data['id'] = element.id;
            data.removeWhere((key, value) => key == 'authorId');
            return [...previousValue, types.Message.fromJson(data)];
          },
        );
      },
    );
  }

  /// Returns last message of this room
  Future<dynamic> lastMessage(types.Room room) async {
    final QuerySnapshot<Map<String, dynamic>> collection =
        await FirebaseFirestore.instance
            .collection('rooms/${room.id}/messages')
            .orderBy('createdAt', descending: true)
            .get();
    final QueryDocumentSnapshot<Map<String, dynamic>> doc =
        collection.docs.last;
    return {
      'message': doc.data()['text'].toString(),
      'authorId': doc.data()['authorId'].toString()
    };
  }

  /// Returns a stream of changes in a room from Firebase
  Stream<types.Room> room(String roomId) {
    if (firebaseUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .asyncMap((doc) => processRoomDocument(doc, firebaseUser!));
  }

  /// Returns a stream of rooms from Firebase. Only rooms where current
  /// logged in user exist are returned.
  Stream<List<types.Room>> rooms() {
    if (firebaseUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('rooms')
        .where('userIds', arrayContains: firebaseUser!.uid)
        .snapshots()
        .asyncMap((query) => processRoomsQuery(firebaseUser!, query));
  }

  /// Sends a message to the Firestore. Accepts any partial message and a
  /// room ID. If arbitraty data is provided in the [partialMessage]
  /// does nothing.
  Future<String?> sendMessage(dynamic partialMessage, String roomId) async {
    if (firebaseUser == null) return null;

    types.Message? message;

    if (partialMessage is types.PartialFile) {
      message = types.FileMessage.fromPartial(
        author: types.User(id: firebaseUser!.uid),
        id: '',
        partialFile: partialMessage,
      );
    } else if (partialMessage is types.PartialImage) {
      message = types.ImageMessage.fromPartial(
        author: types.User(id: firebaseUser!.uid),
        id: '',
        partialImage: partialMessage,
      );
    } else if (partialMessage is types.PartialText) {
      message = types.TextMessage.fromPartial(
        author: types.User(id: firebaseUser!.uid),
        id: '',
        partialText: partialMessage,
      );
    } else if (partialMessage is types.PartialPaymentRequest) {
      message = types.PaymentRequestMessage.fromPartial(
          author: types.User(id: firebaseUser!.uid),
          id: '',
          partialPaymentRequest: partialMessage);
    }

    if (message != null) {
      final messageMap = message.toJson();
      messageMap.removeWhere((key, value) => key == 'author' || key == 'id');
      messageMap['authorId'] = firebaseUser!.uid;
      messageMap['createdAt'] = FieldValue.serverTimestamp();

      String messageId = 'error';
      await FirebaseFirestore.instance
          .collection('rooms/$roomId/messages')
          .add(messageMap)
          .then((value) => messageId = value.id);

      return messageId;
    }
  }

  /// Updates a message in the Firestore. Accepts any message and a
  /// room ID. Message will probably be taken from the [messages] stream.
  void updateMessage(types.Message message, String roomId) async {
    if (firebaseUser == null) return;
    if (message.author.id != firebaseUser!.uid) return;

    final messageMap = message.toJson();
    messageMap.removeWhere((key, value) => key == 'id' || key == 'createdAt');

    await FirebaseFirestore.instance
        .collection('rooms/$roomId/messages')
        .doc(message.id)
        .update(messageMap);
  }

  void updatePaymentRequest(types.PartialPaymentRequest message, String roomId,
      String messageId) async {
    if (firebaseUser == null) return;

    final messageMap = message.toJson();

    await FirebaseFirestore.instance
        .collection('rooms/$roomId/messages')
        .doc(messageId)
        .update(messageMap);
  }

  /// Returns a stream of all users from Firebase
  Stream<List<types.User>> users() {
    if (firebaseUser == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('bijlesgevers')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<List<types.User>>(
            [],
            (previousValue, element) {
              if (firebaseUser!.uid == element.id) return previousValue;

              return [...previousValue, processUserDocument(element)];
            },
          ),
        );
  }
}
