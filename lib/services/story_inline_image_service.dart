import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Gallery image → Firebase Storage under `stories/{uid}/inline/…`.
class StoryInlineImageService {
  StoryInlineImageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  Future<StoryInlineUpload?> pickAndUploadJpeg() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;

    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'stories/${user.uid}/inline/$name';
    final ref = _storage.ref(path);

    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    return StoryInlineUpload(url: url, storagePath: path);
  }
}

class StoryInlineUpload {
  final String url;
  final String storagePath;

  StoryInlineUpload({required this.url, required this.storagePath});
}
