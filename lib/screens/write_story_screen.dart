import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speech_to_text_screen.dart';
import 'theme.dart';
import 'ai_image_generator_screen.dart';
import '../services/content_moderation_service.dart';
import '../widgets/moderation_ui.dart';
import '../services/story_inline_image_service.dart';
import '../utils/story_content.dart';

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
  final TextEditingController _titleController = TextEditingController();
  /// One scroll for title, story blocks, images, and actions (Medium-style flow).
  final ScrollController _storyScrollController = ScrollController();
  final ContentModerationService _moderationService =
      ContentModerationService();
  final StoryInlineImageService _inlineImageService = StoryInlineImageService();
  final List<_WriteSeg> _segments = [];
  /// Last text block that had focus; used by toolbar "Gallery" insert.
  int _lastActiveTextSegmentIndex = 0;
  String? _storyCoverUrl;
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _isUploadingInlineImage = false;
  /// Last removed inline image (SnackBar Undo restores it at [insertIndex]).
  _PendingImageRemoval? _pendingImageRemoval;

  int get _wordCount {
    final plain = _plainBody.trim();
    if (plain.isEmpty) return 0;
    return plain.split(RegExp(r"\s+")).length;
  }

  String get _plainBody => _joinSegmentTexts();

  double get _wordProgress => (_wordCount / 200).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _segments.add(_newTextSegment());
    HardwareKeyboard.instance.addHandler(_onStoryEditorHardwareKey);

    if (widget.storyId != null) {
      _loadExistingStory();
    }
  }

  _WriteSeg _newTextSegment([String initialText = '']) {
    final c = TextEditingController(text: initialText);
    final focus = FocusNode();
    _attachListener(c);
    focus.addListener(() {
      if (!focus.hasFocus) return;
      final i = _segments.indexWhere(
        (s) => !s.isImage && identical(s.focusNode, focus),
      );
      if (i >= 0) _lastActiveTextSegmentIndex = i;
    });
    return _WriteSeg.text(c, focus);
  }

  void _attachListener(TextEditingController c) {
    c.addListener(_onSegmentTextChanged);
  }

  void _detachListener(TextEditingController c) {
    c.removeListener(_onSegmentTextChanged);
  }

  void _onSegmentTextChanged() {
    setState(() {});
  }

  void _scrollStoryToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_storyScrollController.hasClients) return;
      _storyScrollController.jumpTo(
        _storyScrollController.position.maxScrollExtent,
      );
    });
  }

  String _joinSegmentTexts() {
    final parts = <String>[];
    for (final s in _segments) {
      if (!s.isImage) parts.add(s.controller!.text);
    }
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
  }

  void _disposeAllSegments() {
    for (final s in _segments) {
      if (!s.isImage) {
        _detachListener(s.controller!);
        s.focusNode?.dispose();
        s.controller!.dispose();
      }
    }
    _segments.clear();
    _lastActiveTextSegmentIndex = 0;
    _pendingImageRemoval = null;
  }

  /// True when this index is the first text block in the story (images before it are OK).
  bool _isFirstTextSegmentInStory(int index) {
    if (index < 0 || index >= _segments.length || _segments[index].isImage) {
      return false;
    }
    for (var j = 0; j < index; j++) {
      if (!_segments[j].isImage) return false;
    }
    return true;
  }

  /// Joins this text segment into the one above (removes gap after deleting an image, etc.).
  void _mergeTextSegmentIntoPrevious(int index) {
    if (index <= 0) return;
    final prev = _segments[index - 1];
    final curr = _segments[index];
    if (prev.isImage || curr.isImage) return;

    final prevCtrl = prev.controller!;
    final currCtrl = curr.controller!;
    final joinAt = prevCtrl.text.length;
    final merged = prevCtrl.text + currCtrl.text;

    _detachListener(currCtrl);
    curr.focusNode?.dispose();
    currCtrl.dispose();

    setState(() {
      prevCtrl.text = merged;
      _segments.removeAt(index);
      _lastActiveTextSegmentIndex = index - 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      prevCtrl.selection = TextSelection.collapsed(offset: joinAt);
      prev.focusNode?.requestFocus();
    });
  }

  bool _onStoryEditorHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return false;
    if (_isUploadingInlineImage) return false;

    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (seg.isImage) continue;
      final fn = seg.focusNode;
      if (fn == null || !fn.hasFocus) continue;

      final controller = seg.controller!;
      final sel = controller.selection;
      if (!sel.isCollapsed) return false;
      if (sel.baseOffset != 0) return false;
      if (i == 0) return false;
      if (_segments[i - 1].isImage) return false;

      _mergeTextSegmentIntoPrevious(i);
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _serializeContent() {
    final out = <Map<String, dynamic>>[];
    for (final s in _segments) {
      if (s.isImage) {
        out.add(
          StoryContentCodec.imageBlock(
            url: s.imageUrl!,
            storagePath: s.storagePath ?? '',
          ),
        );
      } else {
        out.add(StoryContentCodec.textBlock(s.controller!.text));
      }
    }
    return out;
  }

  /// Index of the text segment whose [FocusNode] currently has focus, or `-1`.
  int _focusedTextSegmentIndex() {
    for (var i = 0; i < _segments.length; i++) {
      final s = _segments[i];
      if (!s.isImage && (s.focusNode?.hasFocus == true)) return i;
    }
    return -1;
  }

  void _focusAndRevealTextSegment(_WriteSeg textSeg) {
    final fn = textSeg.focusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn?.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = fn?.context;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.12,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollStoryToEnd();
        }
      });
    });
  }

  /// Inserts image after the whole text block, then a new empty paragraph (keeps existing controller text).
  void _applyInsertImageAfterSegment(
    int segmentIndex,
    StoryInlineUpload uploaded,
  ) {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;
    if (_segments[segmentIndex].isImage) return;

    final after = segmentIndex + 1;
    final newSeg = _newTextSegment();

    setState(() {
      _segments.insert(
        after,
        _WriteSeg.image(
          url: uploaded.url,
          storagePath: uploaded.storagePath,
        ),
      );
      _segments.insert(after + 1, newSeg);
      _lastActiveTextSegmentIndex = after + 1;
    });
    _focusAndRevealTextSegment(newSeg);
  }

  /// Splits one text segment at [splitOffset] and inserts the image between the two parts.
  void _splitTextSegmentAndInsertImage(
    int segmentIndex,
    int splitOffset,
    StoryInlineUpload uploaded,
  ) {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;
    final old = _segments[segmentIndex];
    if (old.isImage) return;

    final c = old.controller!;
    final text = c.text;
    final off = splitOffset.clamp(0, text.length);
    final leftText = text.substring(0, off);
    final rightText = text.substring(off);

    _detachListener(c);
    old.focusNode?.dispose();
    c.dispose();

    final left = _newTextSegment(leftText);
    final right = _newTextSegment(rightText);
    final img = _WriteSeg.image(
      url: uploaded.url,
      storagePath: uploaded.storagePath,
    );

    setState(() {
      _segments.removeAt(segmentIndex);
      _segments.insertAll(segmentIndex, [left, img, right]);
      _lastActiveTextSegmentIndex = segmentIndex + 2;
    });
    _focusAndRevealTextSegment(right);
  }

  /// Removes only this image block. Paragraphs before and after stay separate (no merge).
  void _removeImageAt(int index) {
    if (index < 0 || index >= _segments.length || !_segments[index].isImage) {
      return;
    }
    final seg = _segments[index];
    final url = seg.imageUrl!;
    final path = seg.storagePath ?? '';

    setState(() {
      _segments.removeAt(index);
    });
    _pendingImageRemoval = _PendingImageRemoval(
      insertIndex: index,
      url: url,
      storagePath: path,
    );
    _lastActiveTextSegmentIndex = _segments.indexWhere((s) => !s.isImage);
    if (_lastActiveTextSegmentIndex < 0) _lastActiveTextSegmentIndex = 0;

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Image removed'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            final pending = _pendingImageRemoval;
            if (pending == null) return;
            final at = pending.insertIndex.clamp(0, _segments.length);
            setState(() {
              _segments.insert(
                at,
                _WriteSeg.image(
                  url: pending.url,
                  storagePath: pending.storagePath,
                ),
              );
              _pendingImageRemoval = null;
            });
          },
        ),
      ),
    );
  }

  /// Swaps this image for another from the gallery; neighboring text segments unchanged.
  Future<void> _replaceImageAt(int index) async {
    if (index < 0 || index >= _segments.length || !_segments[index].isImage) {
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to replace photos.')),
      );
      return;
    }

    setState(() => _isUploadingInlineImage = true);
    try {
      final uploaded = await _inlineImageService.pickAndUploadJpeg();
      if (!mounted || uploaded == null) return;

      setState(() {
        _segments[index] = _WriteSeg.image(
          url: uploaded.url,
          storagePath: uploaded.storagePath,
        );
      });
    } finally {
      if (mounted) setState(() => _isUploadingInlineImage = false);
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
    _storyCoverUrl = data['coverUrl'];

    _disposeAllSegments();
    final raw = StoryContentCodec.parseContent(data['content']);
    if (raw != null && raw.isNotEmpty) {
      for (final m in raw) {
        final type = m['type'] as String?;
        if (type == StoryContentCodec.typeImage) {
          final u = m['url'] as String?;
          final p = m['storagePath'] as String? ?? '';
          if (u != null && u.trim().isNotEmpty) {
            _segments.add(_WriteSeg.image(url: u.trim(), storagePath: p));
          }
        } else {
          final t = m['text'] as String? ?? '';
          _segments.add(_newTextSegment(t));
        }
      }
      if (_segments.isEmpty || _segments.every((s) => s.isImage)) {
        _segments.insert(0, _newTextSegment());
      }
    } else {
      final body = data['body'] as String? ?? '';
      _segments.add(_newTextSegment(body));
    }
    _lastActiveTextSegmentIndex = _segments.indexWhere((s) => !s.isImage);
    if (_lastActiveTextSegmentIndex < 0) _lastActiveTextSegmentIndex = 0;
    if (mounted) setState(() {});
  }

  Future<void> _saveStory({
    bool publish = false,
    bool silent = false,
    bool requireComplete = true,
    bool runModeration = true,
  }) async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final body = _plainBody.trim();
    if (requireComplete && (title.isEmpty || body.isEmpty)) {
      final missingFields = [
        if (title.isEmpty) 'title',
        if (body.isEmpty) 'story body',
      ].join(' and ');
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please add a $missingFields before ${publish ? 'publishing' : 'saving your draft'}.",
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      publish ? _isPublishing = true : _isSaving = true;
    });

    try {
      if (runModeration) {
        final moderation = _moderationService.moderateStory(
          title: title,
          body: body,
        );

        if (!moderation.isSafe) {
          await _showModerationWarning(moderation);
          return;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      final userDoc = uid == null
          ? null
          : await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc?.data() ?? {};
      final savedUsername = (userData['username'] as String?)?.trim();
      final authorName = savedUsername != null && savedUsername.isNotEmpty
          ? savedUsername
          : user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : user?.email?.split('@').first ?? 'Unknown';
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

      final content = _serializeContent();

      final doc = {
        'title': title,
        'body': body,
        'content': content,
        'coverUrl': _storyCoverUrl,
        'wordCount': _wordCount,
        'authorId': uid,
        'authorName': authorName,
        'username': authorName,
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
            .update({
          ...doc,
          if (publish) 'parentFeedback': FieldValue.delete(),
        });
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
          'likedBy': [],
          'comments': 0,
          'saves': 0,
          'savedBy': [],
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
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(publish
                  ? needsParentApproval
                      ? "Sent to your parent for approval."
                      : "Your story is now live in Community! 🚀"
                  : "Story saved to Drafts ✅")),
        );
      }

      if (!silent && widget.storyId == null && !publish) {
        setState(() {
          _titleController.clear();
          _disposeAllSegments();
          _segments.add(_newTextSegment());
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

  bool get _hasDraftableContent {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_plainBody.trim().isNotEmpty) return true;
    if ((_storyCoverUrl ?? '').trim().isNotEmpty) return true;
    return _segments.any((s) => s.isImage);
  }

  Future<void> _saveDraftOnExitIfNeeded() async {
    if (_isSaving || _isPublishing || _isUploadingInlineImage) return;
    if (!_hasDraftableContent) return;
    try {
      await _saveStory(
        publish: false,
        silent: true,
        requireComplete: false,
        runModeration: false,
      );
    } catch (_) {
      // Best-effort auto-save on back navigation.
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
    final storyDescription = _plainBody.trim();
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
    final plainBeforeSpeech = _plainBody;
    final spokenText = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechToTextScreen(
          initialText: plainBeforeSpeech,
        ),
      ),
    );

    if (spokenText is String && mounted) {
      final transcript = spokenText.trim();
      if (_isStoryTranscript(transcript)) {
        _applySpeechTranscript(transcript, plainBeforeSpeech);
      }
    }
  }

  Future<void> _showModerationWarning(ModerationResult result) async {
    if (!mounted) return;
    await ModerationUi.showBlockDialog(
      context,
      result: result,
      surface: ModerationSurface.story,
    );
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
    _disposeAllSegments();
    _segments.add(_newTextSegment(text));
    _lastActiveTextSegmentIndex = 0;
    setState(() {});
    _scrollStoryToEnd();
  }

  /// Applies speech result: full replace when there are no inline images;
  /// otherwise only appends **new** words after [plainBeforeSpeech] so images stay.
  void _applySpeechTranscript(String transcript, String plainBeforeSpeech) {
    final t = transcript.trim();
    if (t.isEmpty) return;

    final hasInlineImages = _segments.any((s) => s.isImage);
    if (!hasInlineImages) {
      _replaceBody(t);
      return;
    }

    final before = plainBeforeSpeech.trim();
    var delta = t;
    if (before.isNotEmpty) {
      if (t == before) return;
      if (t.startsWith(before)) {
        delta = t.substring(before.length).trimLeft();
      }
    }
    if (delta.isEmpty) return;

    var idx = _focusedTextSegmentIndex();
    if (idx < 0 || _segments[idx].isImage) {
      idx = _lastActiveTextSegmentIndex;
    }
    if (idx < 0 || _segments[idx].isImage) {
      idx = _segments.lastIndexWhere((s) => !s.isImage);
    }
    if (idx < 0) {
      setState(() => _segments.add(_newTextSegment(delta)));
      _scrollStoryToEnd();
      return;
    }

    final c = _segments[idx].controller!;
    final cur = c.text.trim();
    final spacer = cur.isEmpty ? '' : '\n\n';
    setState(() {
      c.text = '$cur$spacer$delta';
    });
    _scrollStoryToEnd();
  }

  /// Gallery image at cursor when possible (split paragraph); otherwise after the block.
  Future<void> _insertInlineImageFromGalleryToolbar() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add photos to your story.')),
      );
      return;
    }
    if (_isUploadingInlineImage) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    var idx = _focusedTextSegmentIndex();
    if (idx < 0 || idx >= _segments.length || _segments[idx].isImage) {
      idx = _lastActiveTextSegmentIndex;
      if (idx < 0 || idx >= _segments.length || _segments[idx].isImage) {
        idx = _segments.lastIndexWhere((s) => !s.isImage);
      }
    }
    if (idx < 0) return;

    setState(() => _isUploadingInlineImage = true);
    try {
      final uploaded = await _inlineImageService.pickAndUploadJpeg();
      if (!mounted || uploaded == null) return;

      final c = _segments[idx].controller!;
      final len = c.text.length;
      final sel = c.selection;
      int offset;
      if (sel.isValid) {
        offset = sel.isCollapsed
            ? sel.baseOffset.clamp(0, len)
            : sel.start.clamp(0, len);
      } else {
        offset = len;
      }

      if (offset >= len) {
        _applyInsertImageAfterSegment(idx, uploaded);
      } else {
        _splitTextSegmentAndInsertImage(idx, offset, uploaded);
      }
    } finally {
      if (mounted) setState(() => _isUploadingInlineImage = false);
    }
  }

  Future<void> _handleBack() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _saveDraftOnExitIfNeeded();
    if (!mounted) return;
    final backToCommunity = widget.onBackToCommunity;
    if (backToCommunity != null) {
      backToCommunity();
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onStoryEditorHardwareKey);
    _titleController.dispose();
    _disposeAllSegments();
    _storyScrollController.dispose();
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
        child: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom;
            final horizontalPad =
                mq.size.width < 360 ? 12.0 : (mq.size.width > 840 ? 24.0 : 16.0);

            return Stack(
              children: [
                Scrollbar(
                  controller: _storyScrollController,
                  thumbVisibility: mq.size.width >= 600,
                  child: ListView(
                    controller: _storyScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      16,
                      horizontalPad,
                      24 + bottomInset,
                    ),
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
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              _storyCoverUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Story',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._buildSegmentEditorRows(context),
                      const SizedBox(height: 16),
                      _buildWordProgressSection(),
                      const SizedBox(height: 16),
                      _buildToolbarActions(context),
                      const SizedBox(height: 20),
                      _buildDraftPublishRow(),
                    ],
                  ),
                ),
                if (_isUploadingInlineImage)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.55),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: kAppPrimary),
                              SizedBox(height: 12),
                              Text('Adding photo…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
              hintTextDirection: direction,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  /// Bordered “document” containing text + inline images in order (Medium-style).
  List<Widget> _buildSegmentEditorRows(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 360;
    final isBusy = _isUploadingInlineImage;
    final inner = <Widget>[];
    for (var i = 0; i < _segments.length; i++) {
      final s = _segments[i];
      if (s.isImage) {
        inner.add(_buildImageSegment(i, s));
      } else {
        inner.add(_buildTextSegment(context, i, s));
      }
    }
    inner.add(const SizedBox(height: 2));
    inner.add(
      Align(
        alignment: Alignment.centerLeft,
        child: IgnorePointer(
          ignoring: isBusy,
          child: Opacity(
            opacity: isBusy ? 0.5 : 1,
            child: TextButton.icon(
              onPressed: _insertInlineImageFromGalleryToolbar,
              icon: Icon(
                Icons.add_photo_alternate_outlined,
                size: compact ? 18 : 20,
                color: const Color(0xFF6A1B9A),
              ),
              label: Text(
                'Add image here',
                style: TextStyle(
                  color: const Color(0xFF6A1B9A),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 6 : 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: _fieldDecoration(outlined: true),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: inner,
          ),
        ),
      ),
    ];
  }

  Widget _buildWordProgressSection() {
    final progressColor =
        _wordProgress < 1.0 ? kAppPrimary : Colors.green.shade600;
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
            'Word count: $_wordCount',
            style: TextStyle(
              color: progressColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarActions(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 400;
    final spacing = w < 360 ? 10.0 : 18.0;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: 12,
      children: [
        _buildActionButton(
          icon: Icons.image,
          label: 'To Picture',
          tooltip: 'Create an AI cover image from your story text',
          onTap: _goToAiGenerator,
          color: kAppPrimary,
          compact: compact,
        ),
        IgnorePointer(
          ignoring: _isUploadingInlineImage,
          child: Opacity(
            opacity: _isUploadingInlineImage ? 0.45 : 1,
            child: _buildActionButton(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Add Image',
              tooltip:
                  'Add an image from your gallery after the paragraph you are typing in',
              onTap: _insertInlineImageFromGalleryToolbar,
              color: const Color(0xFF6A1B9A),
              compact: compact,
            ),
          ),
        ),
        _buildActionButton(
          icon: Icons.mic,
          label: 'Speak',
          tooltip: 'Dictate with your voice',
          onTap: _goToSpeechToText,
          color: kAppPrimary,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildDraftPublishRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        final draftBtn = OutlinedButton.icon(
          onPressed: _isSaving ? null : () => _saveStory(publish: false),
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
          label: _isSaving ? const Text('Saving...') : const Text('Draft'),
        );
        final publishBtn = ElevatedButton.icon(
          onPressed: _isPublishing ? null : () => _saveStory(publish: true),
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
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.send),
          label: _isPublishing
              ? const Text('Publishing...')
              : const Text('Publish'),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              draftBtn,
              const SizedBox(height: 10),
              publishBtn,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: draftBtn),
            const SizedBox(width: 12),
            Expanded(child: publishBtn),
          ],
        );
      },
    );
  }

  int _bodyTextMinLinesFor(BuildContext context, int segmentIndex) {
    if (!_isFirstTextSegmentInStory(segmentIndex)) return 1;
    final s = MediaQuery.sizeOf(context).shortestSide;
    if (s >= 700) return 5;
    if (s >= 500) return 4;
    return 3;
  }

  int _bodyTextMaxLinesFor(BuildContext context) {
    final s = MediaQuery.sizeOf(context).shortestSide;
    if (s >= 700) return 20;
    if (s >= 500) return 16;
    return 14;
  }

  Widget _buildTextSegment(BuildContext context, int index, _WriteSeg s) {
    final c = s.controller!;
    final direction = _textDirectionFor(c.text);
    final textAlign = _textAlignFor(direction);
    final isRtl = direction == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        focusNode: s.focusNode,
        onTap: () => _lastActiveTextSegmentIndex = index,
        onTapOutside: (_) =>
            FocusManager.instance.primaryFocus?.unfocus(),
        minLines: _bodyTextMinLinesFor(context, index),
        maxLines: _bodyTextMaxLinesFor(context),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textDirection: direction,
        textAlign: textAlign,
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isRtl ? 4 : 2,
            vertical: isRtl ? 10 : 8,
          ),
        ),
        style: TextStyle(
          color: Colors.black87,
          fontSize: isRtl ? 17 : 16,
          height: isRtl ? 1.65 : 1.55,
        ),
      ),
    );
  }

  Widget _buildImageSegment(int index, _WriteSeg s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final screenH = MediaQuery.sizeOf(context).height;
                final upper = screenH * 0.45 < 440 ? screenH * 0.45 : 440.0;
                final maxH = (w * 0.62).clamp(120.0, upper);
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Image.network(
                    s.imageUrl!,
                    key: ValueKey('${s.imageUrl}_${s.storagePath}'),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final h = maxH.clamp(120.0, 200.0);
                      return SizedBox(
                        height: h,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                );
              },
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 4,
            overflowSpacing: 4,
            children: [
              TextButton.icon(
                onPressed:
                    _isUploadingInlineImage ? null : () => _replaceImageAt(index),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Replace'),
              ),
              TextButton.icon(
                onPressed:
                    _isUploadingInlineImage ? null : () => _removeImageAt(index),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _containsUrdu(String value) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(value);
  }

  /// English / Latin letters (mixed stories should stay left-aligned).
  bool _containsLatinLetters(String value) {
    return RegExp(r'[A-Za-z]').hasMatch(value);
  }

  /// Urdu-only → RTL / right. English-only or **mixed** English+Urdu → LTR /
  /// left; Urdu runs still render RTL inside the line via Unicode bidi.
  TextDirection _textDirectionFor(String value) {
    if (!_containsUrdu(value)) return TextDirection.ltr;
    if (_containsLatinLetters(value)) return TextDirection.ltr;
    return TextDirection.rtl;
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
    String? tooltip,
    bool compact = false,
  }) {
    final dim = compact ? 52.0 : 60.0;
    final iconSize = compact ? 24.0 : 28.0;
    final labelSize = compact ? 12.0 : 13.0;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: dim,
            width: dim,
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
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        child: column,
      );
    }
    return column;
  }
}

class _PendingImageRemoval {
  const _PendingImageRemoval({
    required this.insertIndex,
    required this.url,
    required this.storagePath,
  });
  final int insertIndex;
  final String url;
  final String storagePath;
}

/// One segment in the write screen: a text field or an uploaded inline image.
class _WriteSeg {
  _WriteSeg._({this.controller, this.focusNode, this.imageUrl, this.storagePath});

  factory _WriteSeg.text(TextEditingController c, FocusNode focusNode) =>
      _WriteSeg._(controller: c, focusNode: focusNode);

  factory _WriteSeg.image({
    required String url,
    required String storagePath,
  }) =>
      _WriteSeg._(imageUrl: url, storagePath: storagePath);

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? imageUrl;
  final String? storagePath;

  bool get isImage => controller == null;
}
