import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/story_content.dart';
import '../utils/story_search.dart';
import 'community.dart';
import 'theme.dart';

class ParentApprovalsScreen extends StatefulWidget {
  final String? highlightStoryId;

  const ParentApprovalsScreen({super.key, this.highlightStoryId});

  @override
  State<ParentApprovalsScreen> createState() => _ParentApprovalsScreenState();
}

class _ParentApprovalsScreenState extends State<ParentApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _pendingSearchController =
      TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  Timer? _pendingSearchDebounce;
  Timer? _historySearchDebounce;
  String _pendingSearchQuery = '';
  String _historySearchQuery = '';
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pendingSearchDebounce?.cancel();
    _historySearchDebounce?.cancel();
    _pendingSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (!_isSearchOpen) {
        _pendingSearchDebounce?.cancel();
        _historySearchDebounce?.cancel();
        _pendingSearchController.clear();
        _historySearchController.clear();
        _pendingSearchQuery = '';
        _historySearchQuery = '';
      }
    });
  }

  void _queuePendingSearch(String value) {
    _pendingSearchDebounce?.cancel();
    _pendingSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _pendingSearchQuery = value);
    });
  }

  void _queueHistorySearch(String value) {
    _historySearchDebounce?.cancel();
    _historySearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _historySearchQuery = value);
    });
  }

  bool _matchesStory(Map<String, dynamic> data, String query) {
    return StorySearch.matchesStory(data, query);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final parentEmail = user?.email?.trim().toLowerCase();

    if (parentEmail == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFF9F7FF),
        appBar: AppBar(
          title: const Text(
            'Parent Approvals',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: kAppPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Please log in as a parent.')),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('parentEmail', isEqualTo: parentEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: const Color(0xFFF9F7FF),
            appBar: AppBar(
              title: const Text(
                'Parent Approvals',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: kAppPrimary,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load stories.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: const Color(0xFFF9F7FF),
            appBar: AppBar(
              title: const Text(
                'Parent Approvals',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: kAppPrimary,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: kAppPrimary),
            ),
          );
        }

        final stories = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aDate = _readDate(a.data()['createdAt']);
            final bDate = _readDate(b.data()['createdAt']);
            return bDate.compareTo(aDate);
          });

        final pending = stories
            .where(
              (doc) => doc.data()['status'] == 'pending_parent_approval',
            )
            .toList();
        final history = stories
            .where((doc) =>
                doc.data()['approvalStatus'] == 'approved' ||
                doc.data()['approvalStatus'] == 'rejected')
            .toList()
          ..sort(_compareHistoryStories);

        final pendingCount = pending.length;
        final pendingFiltered = pending
            .where((doc) => _matchesStory(doc.data(), _pendingSearchQuery))
            .toList();
        final historyFiltered = history
            .where((doc) => _matchesStory(doc.data(), _historySearchQuery))
            .toList();

        final pendingPrioritized =
            _prioritizeStory(pendingFiltered, widget.highlightStoryId);
        final hasActivePendingSearch =
            StorySearch.hasSearchTerms(_pendingSearchQuery);
        final hasActiveHistorySearch =
            StorySearch.hasSearchTerms(_historySearchQuery);

        final pendingEmptyText = hasActivePendingSearch
            ? 'No pending stories match your search.'
            : 'No stories waiting for approval.';
        final historyEmptyText = hasActiveHistorySearch
            ? 'No history items match your search.'
            : 'No approval history yet.';

        return Scaffold(
          resizeToAvoidBottomInset: _isSearchOpen,
          backgroundColor: const Color(0xFFF9F7FF),
          appBar: AppBar(
            title: const Text(
              'Parent Approvals',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: kAppPrimary,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: _isSearchOpen ? 'Close search' : 'Search this tab',
                onPressed: _toggleSearch,
                icon: Icon(
                  _isSearchOpen ? Icons.close : Icons.search,
                  color: Colors.white,
                ),
              ),
              if (user != null) _ParentNotificationButton(userId: user.uid),
              IconButton(
                tooltip: 'Logout',
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Confirm Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Logout"),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  child: _PendingTabTitle(count: pendingCount),
                ),
                const Tab(text: 'History'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (_isSearchOpen) ...[
                if (_tabController.index == 0)
                  _ParentApprovalSearchBar(
                    controller: _pendingSearchController,
                    onChanged: _queuePendingSearch,
                    onClear: () {
                      setState(() {
                        _pendingSearchDebounce?.cancel();
                        _pendingSearchController.clear();
                        _pendingSearchQuery = '';
                      });
                    },
                  )
                else
                  _ParentApprovalSearchBar(
                    controller: _historySearchController,
                    onChanged: _queueHistorySearch,
                    onClear: () {
                      setState(() {
                        _historySearchDebounce?.cancel();
                        _historySearchController.clear();
                        _historySearchQuery = '';
                      });
                    },
                  ),
                if (_tabController.index == 0 &&
                    !hasActivePendingSearch &&
                    _pendingSearchQuery.trim().isNotEmpty)
                  const _ParentSearchMinimumHint(),
                if (_tabController.index == 1 &&
                    !hasActiveHistorySearch &&
                    _historySearchQuery.trim().isNotEmpty)
                  const _ParentSearchMinimumHint(),
              ],
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ParentApprovalList(
                      docs: pendingPrioritized,
                      emptyText: pendingEmptyText,
                      showActions: true,
                      highlightStoryId: widget.highlightStoryId,
                    ),
                    _ParentApprovalList(
                      docs: historyFiltered,
                      emptyText: historyEmptyText,
                      showActions: false,
                      highlightStoryId: widget.highlightStoryId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _readReviewedDate(Map<String, dynamic> data) {
    final parentApproval = readStringMap(data['parentApproval']);
    return _readDate(
      parentApproval?['reviewedAt'] ?? data['updatedAt'] ?? data['createdAt'],
    );
  }

  int _compareHistoryStories(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aRejected = aData['approvalStatus'] == 'rejected';
    final bRejected = bData['approvalStatus'] == 'rejected';

    if (aRejected != bRejected) return aRejected ? -1 : 1;

    final aReviewedAt = _readReviewedDate(aData);
    final bReviewedAt = _readReviewedDate(bData);
    return bReviewedAt.compareTo(aReviewedAt);
  }

  static Map<String, dynamic>? readStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _prioritizeStory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? storyId,
  ) {
    if (storyId == null) return docs;
    return docs.toList()
      ..sort((a, b) {
        if (a.id == storyId) return -1;
        if (b.id == storyId) return 1;
        return 0;
      });
  }
}

/// Pending tab label with total count (not affected by search filter).
class _PendingTabTitle extends StatelessWidget {
  final int count;

  const _PendingTabTitle({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Pending'),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ParentApprovalSearchBar extends StatefulWidget {
  static const String _hint = 'Search by Title or keywords';

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ParentApprovalSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_ParentApprovalSearchBar> createState() =>
      _ParentApprovalSearchBarState();
}

class _ParentApprovalSearchBarState extends State<_ParentApprovalSearchBar> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant _ParentApprovalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: widget.controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: _ParentApprovalSearchBar._hint,
            prefixIcon: const Icon(Icons.search, color: kAppPrimary),
            suffixIcon: widget.controller.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: const Color(0xFFF7F3FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2D9F3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2D9F3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kAppPrimary, width: 1.4),
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _ParentSearchMinimumHint extends StatelessWidget {
  const _ParentSearchMinimumHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Enter at least ${StorySearch.minTermLength} characters to search.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ParentApprovalList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String emptyText;
  final bool showActions;
  final String? highlightStoryId;

  const _ParentApprovalList({
    required this.docs,
    required this.emptyText,
    required this.showActions,
    required this.highlightStoryId,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380 ? 12.0 : 16.0;

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(
                  width: double.infinity,
                  child: _ParentApprovalCard(
                    storyId: doc.id,
                    title: (data['title'] as String?) ?? 'Untitled',
                    body: (data['body'] as String?) ?? '',
                    contentBlocks:
                        StoryContentCodec.parseContent(data['content']),
                    childId: data['authorId'] as String?,
                    childName: (data['authorName'] as String?) ?? 'Child',
                    approvalStatus:
                        (data['approvalStatus'] as String?) ?? 'pending',
                    coverUrl: data['coverUrl'] as String?,
                    parentFeedback: _ParentApprovalsScreenState.readStringMap(
                      data['parentFeedback'],
                    ),
                    showActions: showActions,
                    highlighted: doc.id == highlightStoryId,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ParentNotificationButton extends StatelessWidget {
  final String userId;

  const _ParentNotificationButton({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['isRead'] != true)
            .length
            .clamp(0, 99);

        return IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationScreen(
                  userId: userId,
                  onParentApprovalTap: (storyId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentApprovalsScreen(highlightStoryId: storyId),
                      ),
                    );
                  },
                ),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet for parent feedback. Owns [TextEditingController] so the
/// controller is not disposed until after the route removes the [TextField]
/// (disposing it immediately after [showModalBottomSheet] returns can trigger
/// framework assertions during overlay teardown).
class _ParentSendBackFeedbackSheet extends StatefulWidget {
  const _ParentSendBackFeedbackSheet();

  @override
  State<_ParentSendBackFeedbackSheet> createState() =>
      _ParentSendBackFeedbackSheetState();
}

class _ParentSendBackFeedbackSheetState extends State<_ParentSendBackFeedbackSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final feedback = _controller.text.trim();
    if (feedback.isEmpty) {
      setState(() {
        _errorText = 'Please add feedback before sending back.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop<String>(feedback);
  }

  Widget _buildErrorBanner(BuildContext context) {
    if (_errorText == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        _errorText!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safe = mq.padding;

    final horizontalPad = screenW < 360 ? 12.0 : 20.0;
    final titleSize = screenW < 340 ? 18.0 : 22.0;
    final bodySize = screenW < 340 ? 13.0 : 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Prefer the modal's max height (finite after AnimatedPadding in sheet route).
        var maxFromParent = constraints.maxHeight;
        if (!maxFromParent.isFinite || maxFromParent > screenH) {
          maxFromParent = screenH;
        }
        // Fallback: explicit budget above keyboard (viewInsets still visible here).
        final mediaBudget = screenH -
            mq.viewInsets.bottom -
            safe.top -
            safe.bottom -
            20;
        final budget = maxFromParent < mediaBudget ? maxFromParent : mediaBudget;
        var sheetH = budget.clamp(80.0, screenH * 0.94);
        if (maxFromParent.isFinite && sheetH > maxFromParent - 2) {
          sheetH = (maxFromParent - 2).clamp(80.0, screenH * 0.94);
        }
        final sheetW = (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : screenW)
            .clamp(120.0, 720.0);
        final narrowButtons = screenW < 380 || sheetH < 300;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: sheetW - 16 < 100 ? sheetW : sheetW - 16,
            height: sheetH,
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        12,
                        horizontalPad,
                        12 + safe.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Feedback',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'What would you like your child to improve?',
                            style: TextStyle(
                              fontSize: bodySize,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildErrorBanner(context),
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            keyboardType: TextInputType.multiline,
                            minLines: 3,
                            maxLines: 10,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() => _errorText = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'e.g., Check grammar, make it longer, or fix this part...',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FeedbackSheetActions(
                            narrow: narrowButtons,
                            onCancel: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).pop();
                            },
                            onSend: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cancel / Send actions: stacks on narrow widths to avoid horizontal overflow.
class _FeedbackSheetActions extends StatelessWidget {
  final bool narrow;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _FeedbackSheetActions({
    required this.narrow,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cancel = TextButton(
      onPressed: onCancel,
      child: const Text('Cancel'),
    );
    final send = ElevatedButton(
      onPressed: onSend,
      style: ElevatedButton.styleFrom(
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
      ),
      child: const Text('Send Back'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: double.infinity, child: cancel),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: send),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: 8),
        Expanded(child: send),
      ],
    );
  }
}

class _ParentApprovalReview {
  static Future<String?> showFeedbackDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // Lift content above the keyboard; keeps [LayoutBuilder] max height finite.
        final keyboardBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return AnimatedPadding(
          duration: Duration.zero,
          padding: EdgeInsets.only(bottom: keyboardBottom),
          child: const _ParentSendBackFeedbackSheet(),
        );
      },
    );
  }

  static Future<void> submit({
    required String storyId,
    required String title,
    required String? childId,
    required bool approved,
    String? feedback,
  }) async {
    final db = FirebaseFirestore.instance;
    final parent = FirebaseAuth.instance.currentUser;

    try {
      await db.collection('stories').doc(storyId).set({
        'status': approved ? 'published' : 'draft',
        'isPublish': approved,
        'approvalStatus': approved ? 'approved' : 'rejected',
        'parentApproval': {
          'status': approved ? 'approved' : 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': parent?.uid,
          'reviewedByEmail': parent?.email?.trim().toLowerCase(),
        },
        if (approved)
          'parentFeedback': FieldValue.delete()
        else
          'parentFeedback': {
            'feedback': feedback ?? '',
            'givenAt': FieldValue.serverTimestamp(),
            'givenBy': parent?.uid,
            'givenByEmail': parent?.email?.trim().toLowerCase(),
          },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Could not update this story. Sign in with the same parent Gmail '
          'linked on your child\'s profile, then try again.',
        );
      }
      rethrow;
    }

    if (childId == null || childId.isEmpty) return;

    final childSnap = await db.collection('users').doc(childId).get();
    if (childSnap.data()?['notificationsEnabled'] == false) return;

    await db.collection('notifications').add({
      'toUserId': childId,
      'fromUserId': parent?.uid,
      'fromUserName': parent?.displayName ?? 'Parent',
      'type': 'approval_result',
      'storyId': storyId,
      'storyTitle': title,
      'message': approved
          ? 'Your story "$title" was approved and published.'
          : 'Your story "$title" was sent back for editing.',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class _ParentApprovalCard extends StatefulWidget {
  final String storyId;
  final String title;
  final String body;
  final List<Map<String, dynamic>>? contentBlocks;
  final String? childId;
  final String childName;
  final String approvalStatus;
  final String? coverUrl;
  final bool showActions;
  final bool highlighted;
  final Map<String, dynamic>? parentFeedback;

  const _ParentApprovalCard({
    required this.storyId,
    required this.title,
    required this.body,
    this.contentBlocks,
    required this.childId,
    required this.childName,
    required this.approvalStatus,
    required this.coverUrl,
    required this.showActions,
    required this.highlighted,
    this.parentFeedback,
  });

  @override
  State<_ParentApprovalCard> createState() => _ParentApprovalCardState();
}

class _ParentApprovalCardState extends State<_ParentApprovalCard> {
  bool _isSaving = false;

  Future<bool> _review({required bool approved, String? feedback}) async {
    if (!approved) {
      if (feedback == null) {
        feedback = await _ParentApprovalReview.showFeedbackDialog(context);
        if (feedback == null) return false;
        // Let the modal route finish disposing before updating this card
        // (avoids framework assertions during overlay teardown).
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return false;
      }
    } else {
      feedback = null;
    }

    if (!mounted) return false;

    setState(() => _isSaving = true);

    try {
      await _ParentApprovalReview.submit(
        storyId: widget.storyId,
        title: widget.title,
        childId: widget.childId,
        approved: approved,
        feedback: feedback,
      );
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Story approved' : 'Story sent back with feedback',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update story: $error')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _openFullStory() {
    final parent = FirebaseAuth.instance.currentUser;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryReaderPage(
          post: StoryPost(
            id: widget.storyId,
            author: widget.childName,
            handle: widget.childName.replaceAll(' ', '').toLowerCase(),
            title: widget.title,
            excerpt: widget.body,
            likes: 0,
            comments: 0,
            saves: 0,
            ratingCount: 0,
            averageRating: 0,
            likedByMe: false,
            accent: kAppPrimary,
            imageUrl: widget.coverUrl?.isNotEmpty == true
                ? widget.coverUrl!
                : 'https://picsum.photos/seed/${widget.storyId}/600/300',
            contentBlocks: widget.contentBlocks,
          ),
          service: StoryService(),
          userId: parent?.uid ?? '',
          userName: parent?.displayName ?? parent?.email ?? 'Parent',
          footer: widget.showActions
              ? _ParentReviewFooter(
                  storyId: widget.storyId,
                  title: widget.title,
                  childId: widget.childId,
                  onReview: _review,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isNarrow ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.highlighted ? kAppPrimary : const Color(0xFFE2D9F3),
              width: widget.highlighted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'by ${widget.childName}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              _ParentApprovalStatus(status: widget.approvalStatus),
              const SizedBox(height: 10),
              Text(
                widget.body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.35),
              ),
              if (!widget.showActions &&
                  widget.approvalStatus == 'rejected' &&
                  widget.parentFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 16,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Feedback',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.parentFeedback!['feedback'] as String? ??
                            'No specific feedback provided',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.showActions) ...[
                const SizedBox(height: 12),
                if (isNarrow) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _openFullStory,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Read'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _review(approved: false),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Send Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _review(approved: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _openFullStory,
                          icon: const Icon(Icons.menu_book),
                          label: const Text('Read'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _isSaving ? null : () => _review(approved: false),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Send Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSaving ? null : () => _review(approved: true),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAppPrimary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openFullStory,
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Read'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ParentReviewFooter extends StatefulWidget {
  final String storyId;
  final String title;
  final String? childId;
  final Future<bool> Function({
    required bool approved,
    String? feedback,
  }) onReview;

  const _ParentReviewFooter({
    required this.storyId,
    required this.title,
    required this.childId,
    required this.onReview,
  });

  @override
  State<_ParentReviewFooter> createState() => _ParentReviewFooterState();
}

class _ParentReviewFooterState extends State<_ParentReviewFooter> {
  bool _isSaving = false;

  Future<void> _review({required bool approved}) async {
    final String? feedback;
    if (approved) {
      feedback = null;
    } else {
      final entered =
          await _ParentApprovalReview.showFeedbackDialog(context);
      if (entered == null) return;
      feedback = entered;
      // Let the sheet route and keyboard inset settle before rebuilding the
      // reader footer (avoids a brief flex overflow on the story screen).
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!mounted) return;

    setState(() => _isSaving = true);

    var success = false;
    try {
      success = await widget.onReview(
        approved: approved,
        feedback: feedback,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update story: $error')),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      // Pop after the next two frames so layout (insets + reader Column) is
      // stable and we avoid a one-frame bottom overflow flash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sendBackButton = OutlinedButton.icon(
          onPressed: _isSaving ? null : () => _review(approved: false),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.edit_note, size: 17),
          label: const FittedBox(child: Text('Send Back')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade300),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );
        final approveButton = ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _review(approved: true),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 17),
          label: const FittedBox(child: Text('Approve')),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAppPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2D9F3)),
            ),
            child: constraints.maxWidth < 330
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: double.infinity, child: sendBackButton),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: approveButton),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: sendBackButton),
                      const SizedBox(width: 8),
                      Expanded(child: approveButton),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ParentApprovalStatus extends StatelessWidget {
  final String status;

  const _ParentApprovalStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final color = isApproved
        ? Colors.green.shade700
        : isRejected
            ? Colors.orange.shade800
            : Colors.blue.shade700;
    final label = isApproved
        ? 'Approved'
        : isRejected
            ? 'Sent back'
            : 'Waiting for review';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

