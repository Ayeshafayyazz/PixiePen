import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speech_to_text_screen.dart';
import 'theme.dart';
import 'ai_image_generator_screen.dart';
import '../services/content_moderation_service.dart';

class WriteStoryScreen extends StatefulWidget {
  final String? storyId; // optional, for editing existing story
  const WriteStoryScreen({super.key, this.storyId});

  @override
  State<WriteStoryScreen> createState() => _WriteStoryScreenState();
}

class _WriteStoryScreenState extends State<WriteStoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ContentModerationService _moderationService =
      ContentModerationService();
  String? _storyCoverUrl;
  bool _isSaving = false;
  bool _isPublishing = false;

  int get _wordCount {
    if (_bodyController.text.trim().isEmpty) return 0;
    return _bodyController.text.trim().split(RegExp(r"\s+")).length;
  }

  double get _wordProgress => (_wordCount / 200).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    if (widget.storyId != null) {
      _loadExistingStory();
    }
  }

  Future<void> _loadExistingStory() async {
    final doc = await FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyId)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _titleController.text = data['title'] ?? '';
    _bodyController.text = data['body'] ?? '';
    _storyCoverUrl = data['coverUrl'];
    if (mounted) setState(() {});
  }

  Future<void> _saveStory({bool publish = false}) async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      final missingFields = [
        if (title.isEmpty) 'title',
        if (body.isEmpty) 'story body',
      ].join(' and ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please add a $missingFields before ${publish ? 'publishing' : 'saving your draft'}.",
          ),
        ),
      );
      return;
    }

    setState(() {
      publish ? _isPublishing = true : _isSaving = true;
    });

    try {
      final moderation = _moderationService.moderateStory(
        title: title,
        body: body,
      );

      if (!moderation.isSafe) {
        _showModerationWarning();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      final authorName = user?.displayName ?? 'Unknown';
      final userDoc = uid == null
          ? null
          : await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc?.data() ?? {};
      final role = (userData['role'] as String?) ?? 'child';
      final parentEmail =
          (userData['parentEmail'] as String?)?.trim().toLowerCase();
      final isChild = role != 'parent';

      if (publish && isChild && (parentEmail == null || parentEmail.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add your parent Gmail in Edit Profile before publishing.',
            ),
          ),
        );
        return;
      }

      final needsParentApproval = publish && isChild;
      final linkedParentEmail = parentEmail ?? '';
      final storyStatus = needsParentApproval
          ? 'pending_parent_approval'
          : publish
              ? 'published'
              : 'draft';

      final doc = {
        'title': title,
        'body': body,
        'coverUrl': _storyCoverUrl,
        'wordCount': _wordCount,
        'authorId': uid,
        'authorName': authorName,
        'handle': authorName.replaceAll(' ', '').toLowerCase(),
        'status': storyStatus,
        'isPublish': storyStatus == 'published',
        'parentEmail': needsParentApproval ? linkedParentEmail : null,
        'approvalStatus': needsParentApproval
            ? 'pending'
            : storyStatus == 'published'
                ? 'approved'
                : 'not_required',
        'moderation': {
          'isSafe': true,
          'flagReason': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.storyId != null) {
        // Update existing story (draft or published)
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(widget.storyId)
            .update(doc);
        if (needsParentApproval) {
          await _notifyParentForApproval(
            storyId: widget.storyId!,
            title: title,
            authorName: authorName,
            parentEmail: linkedParentEmail,
          );
        }
      } else {
        // Create new story
        final storyRef =
            await FirebaseFirestore.instance.collection('stories').add({
          ...doc,
          'likes': 0,
          'comments': 0,
          'ratingTotal': 0,
          'ratingCount': 0,
          'averageRating': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (needsParentApproval) {
          await _notifyParentForApproval(
            storyId: storyRef.id,
            title: title,
            authorName: authorName,
            parentEmail: linkedParentEmail,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(publish
                ? needsParentApproval
                    ? "Sent to your parent for approval."
                    : "Your story is now live in Community! 🚀"
                : "Story saved to Drafts ✅")),
      );

      // Reset fields only if new story
      if (widget.storyId == null && !publish) {
        setState(() {
          _titleController.clear();
          _bodyController.clear();
          _storyCoverUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Failed to ${publish ? 'publish' : 'save'} story: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          publish ? _isPublishing = false : _isSaving = false;
        });
      }
    }
  }

  Future<void> _notifyParentForApproval({
    required String storyId,
    required String title,
    required String authorName,
    required String parentEmail,
  }) async {
    final parentSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: parentEmail.trim().toLowerCase())
        .limit(1)
        .get();

    if (parentSnap.docs.isEmpty) return;

    final parentDoc = parentSnap.docs.first;
    final parentData = parentDoc.data();
    if (parentData['notificationsEnabled'] == false) return;

    final parentId = parentDoc.id;
    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': parentId,
      'fromUserId': FirebaseAuth.instance.currentUser?.uid,
      'fromUserName': authorName,
      'type': 'parent_approval',
      'storyId': storyId,
      'storyTitle': title,
      'message': '$authorName wants to publish "$title"',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _goToAiGenerator() async {
    final storyDescription = _bodyController.text.trim();
    if (storyDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Write some story before generating image.")),
      );
      return;
    }

    final selectedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiImageGeneratorScreen(
          initialPrompt: storyDescription,
        ),
      ),
    );

    if (selectedImage != null && mounted) {
      setState(() {
        _storyCoverUrl = selectedImage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Cover image added successfully!")),
      );
    }
  }

  Future<void> _goToSpeechToText() async {
    final spokenText = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechToTextScreen(
          initialText: _bodyController.text,
        ),
      ),
    );

    if (spokenText is String && mounted) {
      final transcript = spokenText.trim();
      if (_isStoryTranscript(transcript)) {
        _replaceBody(transcript);
      }
    }
  }

  void _showModerationWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(ContentModerationService.childFriendlyWarning),
    ));
  }

  bool _isStoryTranscript(String text) {
    const statusMessages = {
      'Tap the mic and start speaking...',
      'Listening... Speak now',
      'Microphone permission denied',
      'Speech recognition not available',
    };

    return text.isNotEmpty &&
        !statusMessages.contains(text) &&
        !text.startsWith('Error:');
  }

  void _replaceBody(String text) {
    setState(() {
      _bodyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressColor =
        _wordProgress < 1.0 ? kAppPrimary : Colors.green.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: Text(
            widget.storyId != null ? "Edit Story ✏️" : "Write Your Story ✏️",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTextField(
                controller: _titleController,
                hint: "Enter story title...",
                icon: Icons.title,
                maxLines: 1,
              ),
              if (_storyCoverUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _storyCoverUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _buildTextField(
                  controller: _bodyController,
                  hint: "Start writing your magical story here...",
                  icon: Icons
                      .menu_book, // <-- this will be on the left if _buildTextField uses prefixIcon
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => setState(() {}),
                  outlined: true,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _wordProgress,
                    color: progressColor,
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Word count: $_wordCount / 1000",
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.image,
                    label: "To Picture",
                    onTap: _goToAiGenerator,
                    color: kAppPrimary,
                  ),
                  _buildActionButton(
                    icon: Icons.mic,
                    label: "Speak",
                    onTap: _goToSpeechToText,
                    color: kAppPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _saveStory(publish: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAppPrimary,
                        side: const BorderSide(color: kAppPrimary, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(kAppPrimary),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: _isSaving
                          ? const Text("Saving...")
                          : const Text("Draft"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isPublishing
                          ? null
                          : () => _saveStory(publish: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isPublishing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: _isPublishing
                          ? const Text("Publishing...")
                          : const Text("Publish"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLines,
    bool expands = false,
    Function(String)? onChanged,
    bool outlined = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: outlined
            ? Border.all(color: kAppPrimary, width: 1.8)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        expands: expands,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kAppPrimary),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
