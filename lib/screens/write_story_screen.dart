import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speech_to_text_screen.dart';
import 'theme.dart';
import 'ai_image_generator_screen.dart';
import '../services/content_moderation_service.dart';

class WriteStoryScreen extends StatefulWidget {
  final String? storyId; // optional, for editing existing story
  final VoidCallback? onBackToCommunity;

  const WriteStoryScreen({
    super.key,
    this.storyId,
    this.onBackToCommunity,
  });

  @override
  State<WriteStoryScreen> createState() => _WriteStoryScreenState();
}

class _WriteStoryScreenState extends State<WriteStoryScreen> {
  /// Urdu/Nastaliq needs a tall enough box; keyboard + bottom bar used to
  /// shrink [Expanded] to a few pixels. Editor height is at least this.
  static const double _kStoryEditorMinHeight = 248;

  /// Progress row + action chips + draft/publish row + spacing (below editor).
  static const double _kReservedBelowStoryEditor = 212;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ScrollController _bodyScrollController = ScrollController();
  final FocusNode _bodyFocusNode = FocusNode();
  final ContentModerationService _moderationService =
      ContentModerationService();
  String? _storyCoverUrl;
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _useUrduStoryEditor = false;

  int get _wordCount {
    if (_bodyController.text.trim().isEmpty) return 0;
    return _bodyController.text.trim().split(RegExp(r"\s+")).length;
  }

  double get _wordProgress => (_wordCount / 200).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();

    _bodyController.addListener(_scrollBodyToFollowCaret);

    _bodyFocusNode.addListener(() {
      if (!_bodyFocusNode.hasFocus &&
          _useUrduStoryEditor &&
          !_containsUrdu(_bodyController.text)) {
        _useUrduStoryEditor = false;
      }
      if (mounted) setState(() {});
    });

    if (widget.storyId != null) {
      _loadExistingStory();
    }
  }

  /// Keeps the line you are typing (caret at end) in view. Uses two post-frame
  /// passes so Urdu / IME composition layout finishes before scrolling — a
  /// single immediate [jumpTo] often left RTL composing text off-screen.
  void _scrollBodyToFollowCaret() {
    if (!_bodyFocusNode.hasFocus) return;

    void scrollAfterLayout() {
      if (!mounted) return;
      if (!_bodyScrollController.hasClients) return;

      final value = _bodyController.value;
      final text = value.text;
      final sel = value.selection;
      // When editing earlier text, do not yank scroll to bottom.
      if (!sel.isValid || sel.extentOffset != text.length) return;

      final pos = _bodyScrollController.position;
      final maxExtent = pos.maxScrollExtent;
      if (pos.pixels < maxExtent - 1) {
        pos.jumpTo(maxExtent);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollAfterLayout());
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_bodyScrollController.hasClients) return;
      _bodyScrollController.jumpTo(
        _bodyScrollController.position.maxScrollExtent,
      );
    });
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
    _useUrduStoryEditor = _containsUrdu(_bodyController.text);
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
      _useUrduStoryEditor = _containsUrdu(text);
      _bodyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
    _scrollToBottom();
  }

  void _handleBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    final backToCommunity = widget.onBackToCommunity;
    if (backToCommunity != null) {
      backToCommunity();
      return;
    }
    Navigator.maybePop(context);
  }

  void _handleBodyChanged(String value) {
    final containsUrdu = _containsUrdu(value);
    if (containsUrdu && !_useUrduStoryEditor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_containsUrdu(_bodyController.text)) return;
        setState(() => _useUrduStoryEditor = true);
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _bodyController.removeListener(_scrollBodyToFollowCaret);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyScrollController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back to Community',
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
            widget.storyId != null ? "Edit Story ✏️" : "Write Your Story ✏️",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      hint: "Enter story title...",
                      icon: Icons.title,
                      maxLines: 1,
                      onChanged: (_) => setState(() {}),
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
                    SizedBox(
                      height: _storyEditorBoxHeight(constraints.maxHeight),
                      child: _buildStoryEditor(
                        controller: _bodyController,
                        hint: "Start writing your magical story here...",
                        onChanged: _handleBodyChanged,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bodyController,
                      builder: (context, _, __) {
                        final progressColor = _wordProgress < 1.0
                            ? kAppPrimary
                            : Colors.green.shade600;

                        return Column(
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
                        );
                      },
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
                            onPressed: _isSaving
                                ? null
                                : () => _saveStory(publish: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kAppPrimary,
                              side: const BorderSide(color: kAppPrimary, width: 2),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                                      valueColor: AlwaysStoppedAnimation(
                                          kAppPrimary),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLines,
    Function(String)? onChanged,
    bool outlined = false,
  }) {
    final borderRadius = BorderRadius.circular(14);
    final direction = _textDirectionFor(controller.text);
    final textAlign = _textAlignFor(direction);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: _fieldDecoration(outlined: outlined),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            maxLines: maxLines,
            textDirection: direction,
            textAlign: textAlign,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: kAppPrimary),
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  /// Tall enough to read Urdu glyphs; when the keyboard steals space, the
  /// page scrolls instead of crushing the field to a few pixels.
  double _storyEditorBoxHeight(double bodyViewportMax) {
    final fromLayout = bodyViewportMax - _kReservedBelowStoryEditor;
    return math.max(_kStoryEditorMinHeight, fromLayout);
  }

  Widget _buildStoryEditor({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    final borderRadius = BorderRadius.circular(14);
    final direction = _useUrduStoryEditor
        ? TextDirection.rtl
        : _textDirectionFor(controller.text);
    final textAlign = _textAlignFor(direction);
    final isRtl = direction == TextDirection.rtl;

    final viewInsets = MediaQuery.viewInsetsOf(context);
    // Extra bottom room so the IME can scroll the active line(s) above the
    // keyboard; 20px was too small and Urdu composition often stayed hidden.
    final scrollPadding = EdgeInsets.fromLTRB(
      12,
      72,
      12,
      viewInsets.bottom + 160,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: _fieldDecoration(outlined: true),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Scrollbar(
            controller: _bodyScrollController,
            thumbVisibility: true,
            child: TextField(
              controller: controller,
              focusNode: _bodyFocusNode,
              scrollController: _bodyScrollController,
              onChanged: onChanged,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textDirection: direction,
              textAlign: textAlign,
              textAlignVertical: TextAlignVertical.top,
              scrollPadding: scrollPadding,
              scrollPhysics: const ClampingScrollPhysics(),
              decoration: InputDecoration(
                // LTR only: RTL keeps full width so Urdu lines are not squeezed.
                prefixIcon: direction == TextDirection.ltr
                    ? const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.menu_book, color: kAppPrimary),
                      )
                    : null,
                prefixIconConstraints: direction == TextDirection.ltr
                    ? const BoxConstraints(minWidth: 40, minHeight: 40)
                    : null,
                hintText: hint,
                hintTextDirection: direction,
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isRtl ? 12 : 8,
                  vertical: isRtl ? 14 : 12,
                ),
              ),
              style: TextStyle(
                color: Colors.black87,
                fontSize: isRtl ? 17 : 16,
                height: isRtl ? 1.65 : 1.55,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _containsUrdu(String value) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(value);
  }

  TextDirection _textDirectionFor(String value) {
    return _containsUrdu(value) ? TextDirection.rtl : TextDirection.ltr;
  }

  TextAlign _textAlignFor(TextDirection direction) {
    return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
  }

  BoxDecoration _fieldDecoration({required bool outlined}) {
    return BoxDecoration(
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