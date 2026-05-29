import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts, networkImage;

import 'theme.dart';
import '../utils/pdf_file_exporter.dart';
import '../utils/story_content.dart';
import '../widgets/storage_image.dart';

const _kEbookPageBackground = Color(0xFFF5F5F5);
const _kEbookCardBackground = Color(0xFFFFF4FB);
const _kEbookCardBorder = Color(0xFFEADAE8);
const _kEbookIconBackground = Color(0xFFF1E3F7);
const _kEbookTitleColor = Color(0xFF241627);
const _kEbookMutedText = Color(0xFF5F5262);

/// Apple Books–inspired layout presets: reader colors + PDF tint.
class EbookTemplateDef {
  final String id;
  final String name;
  final String tagline;
  final LinearGradient coverGradient;
  final Color coverBorder;
  final Color coverTitleColor;
  final Color coverAuthorColor;
  final Color readerScaffoldBg;
  final Color readerCardBg;
  final Color readerCardBorder;
  final Color readerStoryTitleColor;
  final Color readerBodyColor;
  final Color readerPartLabelColor;
  final double readerTitleSize;
  final double readerBodySize;
  final bool useSerifBody;

  const EbookTemplateDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.coverGradient,
    required this.coverBorder,
    required this.coverTitleColor,
    required this.coverAuthorColor,
    required this.readerScaffoldBg,
    required this.readerCardBg,
    required this.readerCardBorder,
    required this.readerStoryTitleColor,
    required this.readerBodyColor,
    required this.readerPartLabelColor,
    required this.readerTitleSize,
    required this.readerBodySize,
    this.useSerifBody = false,
  });
}

class EbookTemplateCatalog {
  static final List<EbookTemplateDef> all = [
    EbookTemplateDef(
      id: 'classic',
      name: 'Storybook',
      tagline: 'Soft violet • PixiePen default',
      coverGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF4FB), Color(0xFFE8DDF5)],
      ),
      coverBorder: kAppPrimary,
      coverTitleColor: _kEbookTitleColor,
      coverAuthorColor: _kEbookMutedText,
      readerScaffoldBg: Color(0xFFF2F0F5),
      readerCardBg: Color(0xFFFFF8FD),
      readerCardBorder: Color(0xFFEADAE8),
      readerStoryTitleColor: _kEbookTitleColor,
      readerBodyColor: Color(0xFF242124),
      readerPartLabelColor: _kEbookMutedText,
      readerTitleSize: 24,
      readerBodySize: 18,
    ),
    EbookTemplateDef(
      id: 'paper',
      name: 'Paper',
      tagline: 'Warm paper • book serif text',
      coverGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDFBF7), Color(0xFFE8E0D5)],
      ),
      coverBorder: Color(0xFF8D7B68),
      coverTitleColor: Color(0xFF2C241C),
      coverAuthorColor: Color(0xFF6B5E54),
      readerScaffoldBg: Color(0xFFF5F1EA),
      readerCardBg: Color(0xFFFDFBF7),
      readerCardBorder: Color(0xFFD9D0C3),
      readerStoryTitleColor: Color(0xFF2C241C),
      readerBodyColor: Color(0xFF3D342B),
      readerPartLabelColor: Color(0xFF7A6E63),
      readerTitleSize: 23,
      readerBodySize: 17.5,
      useSerifBody: true,
    ),
    EbookTemplateDef(
      id: 'night',
      name: 'Night',
      tagline: 'Dark mode • easy on the eyes',
      coverGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
      ),
      coverBorder: Color(0xFF48484A),
      coverTitleColor: Color(0xFFF2F2F7),
      coverAuthorColor: Color(0xFFAEAEB2),
      readerScaffoldBg: Color(0xFF1C1C1E),
      readerCardBg: Color(0xFF2C2C2E),
      readerCardBorder: Color(0xFF3A3A3C),
      readerStoryTitleColor: Color(0xFFF2F2F7),
      readerBodyColor: Color(0xFFE5E5EA),
      readerPartLabelColor: Color(0xFF8E8E93),
      readerTitleSize: 24,
      readerBodySize: 18,
    ),
    EbookTemplateDef(
      id: 'mint',
      name: 'Fresh',
      tagline: 'Mint accent • clean & modern',
      coverGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4FFFB), Color(0xFFD8F5EE)],
      ),
      coverBorder: Color(0xFF34C759),
      coverTitleColor: Color(0xFF1A3D36),
      coverAuthorColor: Color(0xFF3D5C54),
      readerScaffoldBg: Color(0xFFEEF8F4),
      readerCardBg: Color(0xFFFFFFFF),
      readerCardBorder: Color(0xFFBFE8D9),
      readerStoryTitleColor: Color(0xFF1A3D36),
      readerBodyColor: Color(0xFF253630),
      readerPartLabelColor: Color(0xFF5C7A72),
      readerTitleSize: 24,
      readerBodySize: 18,
    ),
    EbookTemplateDef(
      id: 'sunset',
      name: 'Sunset',
      tagline: 'Peach glow • cozy chapters',
      coverGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF5F0), Color(0xFFFFE0D6)],
      ),
      coverBorder: Color(0xFFFF8A65),
      coverTitleColor: Color(0xFF4A2C2A),
      coverAuthorColor: Color(0xFF8D6E63),
      readerScaffoldBg: Color(0xFFFFF7F4),
      readerCardBg: Color(0xFFFFFDFC),
      readerCardBorder: Color(0xFFFFCCBC),
      readerStoryTitleColor: Color(0xFF4A2C2A),
      readerBodyColor: Color(0xFF3E2723),
      readerPartLabelColor: Color(0xFF8D6E63),
      readerTitleSize: 24,
      readerBodySize: 18,
    ),
  ];

  static EbookTemplateDef byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}

TextStyle _ebookReaderBody(EbookTemplateDef t) {
  final base = TextStyle(
    fontSize: t.readerBodySize,
    height: 1.55,
    color: t.readerBodyColor,
  );
  if (t.useSerifBody) return GoogleFonts.literata(textStyle: base);
  return GoogleFonts.plusJakartaSans(textStyle: base);
}

class EbookScreen extends StatefulWidget {
  const EbookScreen({super.key});

  @override
  State<EbookScreen> createState() => _EbookScreenState();
}

class _EbookScreenState extends State<EbookScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String? _exportingEbookId;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return _buildLoggedOutScaffold();
    }

    return Scaffold(
      backgroundColor: _kEbookPageBackground,
      appBar: _buildAppBar('My E-Books'),
      body: _buildEbookLibrarySection(),
    );
  }

  Widget _buildLoggedOutScaffold() {
    return Scaffold(
      appBar: _buildAppBar('E-Book Creator'),
      body: const Center(child: Text('Please log in to create an eBook.')),
    );
  }

  Widget _buildEbookLibrarySection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('ebooks')
          .where('userId', isEqualTo: _user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        final ebooks = (snapshot.data?.docs ?? [])
            .map(Ebook.fromDocument)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return _buildLibraryList(ebooks);
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(child: Text('Could not load eBooks: $error'));
  }

  Widget _buildLibraryList(List<Ebook> ebooks) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ebooks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeaderSection();
        }
        final ebook = ebooks[index - 1];
        return _buildBookCard(ebook);
      },
    );
  }

  Widget _buildHeaderSection() {
    return _CreateEbookCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EbookCreatorScreen()),
        );
      },
    );
  }

  Widget _buildBookCard(Ebook ebook) {
    return _EbookLibraryCard(
      ebook: ebook,
      isExporting: _exportingEbookId == ebook.ebookId,
      onRead: () => _openEbook(ebook),
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EbookCreatorScreen(editing: ebook)),
        );
      },
      onDownload: () => _exportEbook(ebook, share: false),
      onShare: () => _exportEbook(ebook, share: true),
      onDelete: () => _confirmDeleteEbook(ebook),
    );
  }

  Future<void> _confirmDeleteEbook(Ebook ebook) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete eBook?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _db.collection('ebooks').doc(ebook.ebookId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('eBook deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete eBook: $error')),
      );
    }
  }

  Future<void> _exportEbook(Ebook ebook, {required bool share}) async {
    setState(() => _exportingEbookId = ebook.ebookId);

    try {
      final stories = await _loadStoriesForEbook(ebook);
      final bytes = await EbookPdfGenerator.buildPdf(ebook, stories);
      final fileName = '${EbookPdfGenerator.safeFileName(ebook.title)}.pdf';

      if (share) {
        await PdfFileExporter.share(bytes: bytes, fileName: fileName);
      } else {
        await PdfFileExporter.download(bytes: bytes, fileName: fileName);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export eBook: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingEbookId = null);
      }
    }
  }

  Future<void> _openEbook(Ebook ebook) async {
    try {
      final stories = await _loadStoriesForEbook(ebook);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EbookReaderScreen(
            ebook: ebook,
            stories: stories,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open eBook: $error')),
      );
    }
  }

  Future<List<StoryBookItem>> _loadStoriesForEbook(Ebook ebook) async {
    final docs = <DocumentSnapshot<Map<String, dynamic>>>[];

    for (final storyId in ebook.storyIds) {
      try {
        final doc = await _db.collection('stories').doc(storyId).get();
        docs.add(doc);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }

    final storiesById = {
      for (final doc in docs)
        if (doc.exists) doc.id: StoryBookItem.fromDocument(doc),
    };

    return [
      for (final storyId in ebook.storyIds)
        if (storiesById[storyId] != null) storiesById[storyId]!,
    ];
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: kAppPrimary,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}

class EbookCreatorScreen extends StatefulWidget {
  /// When set, saves changes to this book instead of creating a new one.
  final Ebook? editing;

  const EbookCreatorScreen({super.key, this.editing});

  @override
  State<EbookCreatorScreen> createState() => _EbookCreatorScreenState();
}

class _EbookCreatorScreenState extends State<EbookCreatorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  String _selectedTemplateId = 'classic';
  List<StoryBookItem> _selectedStories = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.editing;
    if (existing != null) {
      _titleController.text = existing.title;
      _selectedTemplateId = existing.templateId;
      _loadStoriesForEdit(existing);
    }
  }

  Future<void> _loadStoriesForEdit(Ebook ebook) async {
    if (_user == null) return;
    try {
      final list = <StoryBookItem>[];
      for (final id in ebook.storyIds) {
        final doc = await _db.collection('stories').doc(id).get();
        if (doc.exists) list.add(StoryBookItem.fromDocument(doc));
      }
      if (mounted) setState(() => _selectedStories = list);
    } catch (_) {
      /* keep partial list */
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _chooseStories() async {
    final selectedStories = await Navigator.push<List<StoryBookItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPickerScreen(
          initiallySelectedStories: _selectedStories,
        ),
      ),
    );

    if (selectedStories != null && mounted) {
      setState(() => _selectedStories = selectedStories);
    }
  }

  Future<void> _createEbook() async {
    final user = _user;
    if (user == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedStories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title and choose at least one story.'),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final coverImage = _selectedStories
          .map((story) => story.coverUrl)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);

      final existing = widget.editing;
      if (existing != null) {
        await _db.collection('ebooks').doc(existing.ebookId).update({
          'title': title,
          'authorName': user.displayName ?? _selectedStories.first.authorName,
          'coverImage': coverImage,
          'storyIds': _selectedStories.map((story) => story.id).toList(),
          'templateId': _selectedTemplateId,
        });

        final ebook = Ebook(
          ebookId: existing.ebookId,
          userId: existing.userId,
          title: title,
          authorName: user.displayName ?? _selectedStories.first.authorName,
          coverImage: coverImage,
          storyIds: _selectedStories.map((story) => story.id).toList(),
          createdAt: existing.createdAt,
          templateId: _selectedTemplateId,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EbookReaderScreen(
              ebook: ebook,
              stories: _selectedStories,
            ),
          ),
        );
        return;
      }

      final ebookRef = _db.collection('ebooks').doc();
      final ebook = Ebook(
        ebookId: ebookRef.id,
        userId: user.uid,
        title: title,
        authorName: user.displayName ?? _selectedStories.first.authorName,
        coverImage: coverImage,
        storyIds: _selectedStories.map((story) => story.id).toList(),
        createdAt: DateTime.now(),
        templateId: _selectedTemplateId,
      );

      await ebookRef.set(ebook.toFirestore());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EbookReaderScreen(
            ebook: ebook,
            stories: _selectedStories,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final isEdit = widget.editing != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Could not update eBook: $error'
                : 'Could not create eBook: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    if (_user == null) {
      return Scaffold(
        appBar: _buildAppBar(isEditing ? 'Edit E-Book' : 'Create E-Book'),
        body: const Center(child: Text('Please log in to create an eBook.')),
      );
    }

    return Scaffold(
      backgroundColor: _kEbookPageBackground,
      appBar: _buildAppBar(isEditing ? 'Edit E-Book' : 'Create E-Book'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Choose a template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _kEbookTitleColor,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a look — you can change stories anytime.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: _kEbookMutedText,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EbookTemplateCatalog.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final t = EbookTemplateCatalog.all[index];
                final selected = _selectedTemplateId == t.id;
                return _TemplateChoiceCard(
                  template: t,
                  selected: selected,
                  onTap: () => setState(() => _selectedTemplateId = t.id),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _EbookHeader(
            controller: _titleController,
            selectedCount: _selectedStories.length,
            onChooseStories: _chooseStories,
            onCreate: _isCreating ? null : _createEbook,
            isCreating: _isCreating,
            primaryActionLabel: isEditing ? 'Save' : 'Preview',
          ),
          if (_selectedStories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Stories in this book',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _kEbookTitleColor,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_selectedStories.length} items',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kAppPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossCount = w >= 520 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: crossCount == 2 ? 0.82 : 1.15,
                  ),
                  itemCount: _selectedStories.length,
                  itemBuilder: (context, index) {
                    return _SelectedStoryGridTile(
                      story: _selectedStories[index],
                      index: index + 1,
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: kAppPrimary,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}

class StoryPickerScreen extends StatefulWidget {
  final List<StoryBookItem> initiallySelectedStories;

  const StoryPickerScreen({
    super.key,
    required this.initiallySelectedStories,
  });

  @override
  State<StoryPickerScreen> createState() => _StoryPickerScreenState();
}

class _StoryPickerScreenState extends State<StoryPickerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  late final Set<String> _selectedStoryIds;
  late final Map<String, StoryBookItem> _selectedStoriesById;

  @override
  void initState() {
    super.initState();
    _selectedStoryIds =
        widget.initiallySelectedStories.map((story) => story.id).toSet();
    _selectedStoriesById = {
      for (final story in widget.initiallySelectedStories) story.id: story,
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _userStoriesStream() {
    return _db
        .collection('stories')
        .where('authorId', isEqualTo: _user!.uid)
        .snapshots();
  }

  void _finishSelection() {
    final selectedStories = [
      for (final storyId in _selectedStoryIds)
        if (_selectedStoriesById[storyId] != null)
          _selectedStoriesById[storyId]!,
    ];

    Navigator.pop(context, selectedStories);
  }

  bool _isEligibleForEbook(StoryBookItem story) {
    // Only allow published stories (approved by parents and in community)
    return story.status == 'published';
  }

  /// Draft body can be empty when the author used only photos (`content` blocks).
  bool _hasPickableStoryBody(StoryBookItem story) {
    if (story.body.trim().isNotEmpty) return true;
    final c = story.content;
    if (c == null || c.isEmpty) return false;
    if (StoryContentCodec.hasRichLayout(c)) return true;
    return StoryContentCodec.joinPlainText(c).trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: _buildAppBar('Choose Stories'),
        body: const Center(child: Text('Please log in to choose stories.')),
      );
    }

    return Scaffold(
      backgroundColor: _kEbookPageBackground,
      appBar: _buildAppBar('Choose Stories'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _selectedStoryIds.isEmpty ? null : _finishSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text('Use ${_selectedStoryIds.length} selected'),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userStoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load stories: ${snapshot.error}'));
          }

          final stories = (snapshot.data?.docs ?? [])
              .map(StoryBookItem.fromDocument)
              .where(_hasPickableStoryBody)
              .where((story) => _isEligibleForEbook(story))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (stories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Publish a story and get approval from your parents first, then come back to turn it into a book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, height: 1.4),
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cross = w >= 480 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: cross == 2 ? 0.68 : 0.74,
                ),
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final isSelected = _selectedStoryIds.contains(story.id);

                  return _StoryPickerGridTile(
                    story: story,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedStoryIds.remove(story.id);
                          _selectedStoriesById.remove(story.id);
                        } else {
                          _selectedStoryIds.add(story.id);
                          _selectedStoriesById[story.id] = story;
                        }
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: kAppPrimary,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}

class EbookReaderScreen extends StatefulWidget {
  final Ebook ebook;
  final List<StoryBookItem> stories;

  const EbookReaderScreen({
    super.key,
    required this.ebook,
    required this.stories,
  });

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  late final PageController _pageController;
  late final List<EbookPageData> _pages;
  int _currentPage = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = buildEbookPages(widget.ebook, widget.stories);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf({required bool share}) async {
    setState(() => _isExporting = true);

    try {
      final bytes = await _buildPdf();
      final fileName = '${_safeFileName(widget.ebook.title)}.pdf';

      if (share) {
        await PdfFileExporter.share(bytes: bytes, fileName: fileName);
      } else {
        await PdfFileExporter.download(bytes: bytes, fileName: fileName);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<Uint8List> _buildPdf() async =>
      EbookPdfGenerator.buildPdf(widget.ebook, widget.stories);

  String _safeFileName(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'pixiepen_ebook' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final template = EbookTemplateCatalog.byId(widget.ebook.templateId);

    return Scaffold(
      backgroundColor: template.readerScaffoldBg,
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.ebook.title,
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _isExporting ? null : () => _exportPdf(share: false),
            icon: const Icon(Icons.download, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _isExporting ? null : () => _exportPdf(share: true),
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: page.isCover
                          ? _BookCoverPage(
                              ebook: page.ebook!,
                              template: template,
                            )
                          : _StoryChapterPage(
                              story: page.story!,
                              template: template,
                            ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _pages.length,
                        minHeight: 8,
                        color: kAppPrimary,
                        backgroundColor: template.readerCardBorder
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentPage + 1}/${_pages.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: template.readerStoryTitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isExporting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Building your PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateChoiceCard extends StatelessWidget {
  final EbookTemplateDef template;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChoiceCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kAppPrimary : Colors.black12,
            width: selected ? 2.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.12 : 0.06),
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: template.coverGradient),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: template.coverTitleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      template.tagline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        height: 1.25,
                        color: template.coverAuthorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: kAppPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedStoryGridTile extends StatelessWidget {
  final StoryBookItem story;
  final int index;

  const _SelectedStoryGridTile({
    required this.story,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kEbookCardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                story.coverUrl != null && story.coverUrl!.isNotEmpty
                    ? StorageImage(
                        url: story.coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: _tilePlaceholder(),
                      )
                    : _tilePlaceholder(),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kAppPrimary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kEbookTitleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      story.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        height: 1.25,
                        color: _kEbookMutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tilePlaceholder() {
    return Container(
      color: _kEbookIconBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.auto_stories, color: kAppPrimary, size: 36),
    );
  }
}

class _CreateEbookCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateEbookCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kEbookCardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAppPrimary, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: _kEbookIconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_circle, color: kAppPrimary, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a new eBook',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _kEbookTitleColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add a title, choose stories, then preview and export.',
                    style: TextStyle(
                      color: _kEbookMutedText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kAppPrimary),
          ],
        ),
      ),
    );
  }
}

class _EbookLibraryCard extends StatelessWidget {
  final Ebook ebook;
  final bool isExporting;
  final VoidCallback onRead;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _EbookLibraryCard({
    required this.ebook,
    required this.isExporting,
    required this.onRead,
    required this.onEdit,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kEbookCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kEbookCardBorder, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 9,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _StoryThumbnail(imageUrl: ebook.coverImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ebook.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kEbookTitleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kAppPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        EbookTemplateCatalog.byId(ebook.templateId).name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kAppPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'by ${ebook.authorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kEbookMutedText),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${ebook.storyIds.length} ${ebook.storyIds.length == 1 ? 'story' : 'stories'}',
                    style: const TextStyle(
                      color: kAppPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onRead,
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text('Read'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAppPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (isExporting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Edit stories & cover',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: kAppPrimary),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, color: kAppPrimary),
                  ),
                  IconButton(
                    tooltip: 'Export PDF',
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share, color: kAppPrimary),
                  ),
                ],
                IconButton(
                  tooltip: 'Delete eBook',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EbookHeader extends StatelessWidget {
  final TextEditingController controller;
  final int selectedCount;
  final VoidCallback onChooseStories;
  final VoidCallback? onCreate;
  final bool isCreating;
  final String primaryActionLabel;

  const _EbookHeader({
    required this.controller,
    required this.selectedCount,
    required this.onChooseStories,
    required this.onCreate,
    required this.isCreating,
    this.primaryActionLabel = 'Preview',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kEbookCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kEbookCardBorder, width: 1.1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose stories for your book',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _kEbookTitleColor,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Book title',
              prefixIcon: const Icon(Icons.auto_stories),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onChooseStories,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kEbookCardBorder, width: 1.4),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _kEbookIconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.library_books, color: kAppPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose stories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kEbookTitleColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedCount == 0
                              ? 'Open your story list and pick chapters'
                              : '$selectedCount selected for this book',
                          style: const TextStyle(color: _kEbookMutedText),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kAppPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedCount selected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kAppPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAppPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.menu_book),
                label: Text(
                  isCreating
                      ? (primaryActionLabel == 'Save' ? 'Saving' : 'Creating')
                      : primaryActionLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryPickerGridTile extends StatelessWidget {
  final StoryBookItem story;
  final bool isSelected;
  final VoidCallback onTap;

  const _StoryPickerGridTile({
    required this.story,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? kAppPrimary : _kEbookCardBorder,
              width: isSelected ? 2.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.05),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 12,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      story.coverUrl != null && story.coverUrl!.isNotEmpty
                          ? StorageImage(
                              url: story.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: _ph(),
                            )
                          : _ph(),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected ? Colors.lightGreenAccent : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kEbookTitleColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          story.preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            height: 1.25,
                            color: _kEbookMutedText,
                          ),
                        ),
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
  }

  Widget _ph() {
    return Container(
      color: _kEbookIconBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.auto_stories, color: kAppPrimary, size: 40),
    );
  }
}

class _StoryThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _StoryThumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 86,
        width: 70,
        color: _kEbookIconBackground,
        child: url == null || url.isEmpty
            ? const Icon(Icons.auto_stories, color: kAppPrimary, size: 34)
            : StorageImage(
                url: url,
                fit: BoxFit.cover,
                placeholder: const Icon(
                  Icons.auto_stories,
                  color: kAppPrimary,
                  size: 34,
                ),
              ),
      ),
    );
  }
}

class _BookCoverPage extends StatelessWidget {
  final Ebook ebook;
  final EbookTemplateDef template;

  const _BookCoverPage({
    required this.ebook,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final maxArtH = math.min(380.0, w * 0.95);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: template.coverGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: template.coverBorder, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ebook.coverImage != null && ebook.coverImage!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: w,
                      maxHeight: maxArtH,
                    ),
                    child: StorageImage(
                      url: ebook.coverImage,
                      width: w,
                      fit: BoxFit.contain,
                      placeholder: const SizedBox.shrink(),
                    ),
                  ),
                ),
              SizedBox(height: ebook.coverImage != null ? 22 : 0),
              Text(
                ebook.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: template.coverTitleColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'by ${ebook.authorName}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: template.coverAuthorColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One swipe per story: title block once at the top, then text + inline images
/// in editor order in a single scroll (like a printed book chapter).
class _StoryChapterPage extends StatelessWidget {
  final StoryBookItem story;
  final EbookTemplateDef template;

  const _StoryChapterPage({
    required this.story,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = ebookStoryBlocks(story);
    final bodyStyle = _ebookReaderBody(template);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: template.readerCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: template.readerCardBorder, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentW = constraints.maxWidth;
          final maxChapterCoverH = math.min(240.0, contentW * 0.56);
          final maxInlineImageH = math.min(320.0, contentW * 0.78);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                story.title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: template.readerStoryTitleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'by ${story.authorName}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: template.readerPartLabelColor,
                ),
              ),
              if (story.coverUrl != null && story.coverUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: contentW,
                      maxHeight: maxChapterCoverH,
                    ),
                    child: StorageImage(
                      url: story.coverUrl,
                      width: contentW,
                      fit: BoxFit.contain,
                      placeholder: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final block in blocks)
                        ..._widgetsForBlock(
                          block,
                          bodyStyle,
                          contentW,
                          maxInlineImageH,
                        ),
                      if (_chapterBodyIsEmpty(blocks))
                        Text(
                          '(This story is empty.)',
                          style: bodyStyle,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _chapterBodyIsEmpty(List<Map<String, dynamic>> blocks) {
    for (final m in blocks) {
      final type = m['type'] as String?;
      if (type == StoryContentCodec.typeImage &&
          ((m['url'] as String?)?.trim().isNotEmpty ?? false)) {
        return false;
      }
      if (type != StoryContentCodec.typeImage) {
        final t = (m['text'] as String?)?.trim() ?? '';
        if (t.isNotEmpty) return false;
      }
    }
    return true;
  }

  List<Widget> _widgetsForBlock(
    Map<String, dynamic> block,
    TextStyle bodyStyle,
    double contentWidth,
    double maxImageHeight,
  ) {
    final type = block['type'] as String?;
    if (type == StoryContentCodec.typeImage) {
      final url = (block['url'] as String?)?.trim();
      if (url == null || url.isEmpty) return const [];
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentWidth,
                maxHeight: maxImageHeight,
              ),
              child: StorageImage(
                url: url,
                width: contentWidth,
                fit: BoxFit.contain,
                placeholder: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ];
    }

    final raw = (block['text'] as String?) ?? '';
    if (raw.trim().isEmpty) return const [];

    final paragraphs = raw.split(RegExp(r'\n\s*\n'));
    final out = <Widget>[];
    for (final para in paragraphs) {
      final p = para.trim();
      if (p.isEmpty) continue;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(p, style: bodyStyle),
        ),
      );
    }
    return out;
  }
}

class _PdfExportTheme {
  final PdfColor coverBg;
  final PdfColor coverBorder;
  final PdfColor coverTitle;
  final PdfColor coverAuthor;
  final PdfColor cardBg;
  final PdfColor cardBorder;
  final PdfColor storyTitle;
  final PdfColor body;
  final PdfColor muted;

  const _PdfExportTheme({
    required this.coverBg,
    required this.coverBorder,
    required this.coverTitle,
    required this.coverAuthor,
    required this.cardBg,
    required this.cardBorder,
    required this.storyTitle,
    required this.body,
    required this.muted,
  });
}

/// Shared A4 metrics so cover, MultiPage chapters, and images stay aligned for export/share/print.
abstract final class _EbookPdfLayout {
  _EbookPdfLayout._();

  static const double marginPt = 40;

  static PdfPageFormat get pageFormat => PdfPageFormat.a4;

  /// Printable width inside left+right margins (points).
  static double contentWidthPt(PdfPageFormat format) =>
      format.width - 2 * marginPt;

  /// Height inside margins for one PDF sheet (A4 minus margins).
  static double innerHeightPt(PdfPageFormat format) =>
      format.height - 2 * marginPt;

  /// Room left on cover after title, subtitle, padding — avoids single-page overflow.
  static double maxBookCoverArtHeightPt(PdfPageFormat format) =>
      math.min(300.0, innerHeightPt(format) - 230).clamp(72.0, 300.0);

  static double maxChapterCoverHeightPt(PdfPageFormat format) =>
      math.min(220.0, innerHeightPt(format) * 0.28).clamp(72.0, 220.0);

  static double maxInlineImageHeightPt(PdfPageFormat format) =>
      math.min(280.0, innerHeightPt(format) * 0.34).clamp(72.0, 280.0);
}

_PdfExportTheme _pdfExportThemeFor(String? templateId) {
  switch (templateId ?? 'classic') {
    case 'paper':
      return _PdfExportTheme(
        coverBg: PdfColor.fromHex('FDFBF7'),
        coverBorder: PdfColor.fromHex('8D7B68'),
        coverTitle: PdfColor.fromHex('2C241C'),
        coverAuthor: PdfColor.fromHex('6B5E54'),
        cardBg: PdfColor.fromHex('FDFBF7'),
        cardBorder: PdfColor.fromHex('D9D0C3'),
        storyTitle: PdfColor.fromHex('2C241C'),
        body: PdfColor.fromHex('3D342B'),
        muted: PdfColor.fromHex('7A6E63'),
      );
    case 'night':
      return _PdfExportTheme(
        coverBg: PdfColor.fromHex('2C2C2E'),
        coverBorder: PdfColor.fromHex('48484A'),
        coverTitle: PdfColor.fromHex('F2F2F7'),
        coverAuthor: PdfColor.fromHex('AEAEB2'),
        cardBg: PdfColor.fromHex('2C2C2E'),
        cardBorder: PdfColor.fromHex('3A3A3C'),
        storyTitle: PdfColor.fromHex('F2F2F7'),
        body: PdfColor.fromHex('E5E5EA'),
        muted: PdfColor.fromHex('8E8E93'),
      );
    case 'mint':
      return _PdfExportTheme(
        coverBg: PdfColor.fromHex('FFFFFF'),
        coverBorder: PdfColor.fromHex('34C759'),
        coverTitle: PdfColor.fromHex('1A3D36'),
        coverAuthor: PdfColor.fromHex('3D5C54'),
        cardBg: PdfColor.fromHex('FFFFFF'),
        cardBorder: PdfColor.fromHex('BFE8D9'),
        storyTitle: PdfColor.fromHex('1A3D36'),
        body: PdfColor.fromHex('253630'),
        muted: PdfColor.fromHex('5C7A72'),
      );
    case 'sunset':
      return _PdfExportTheme(
        coverBg: PdfColor.fromHex('FFFDFC'),
        coverBorder: PdfColor.fromHex('FF8A65'),
        coverTitle: PdfColor.fromHex('4A2C2A'),
        coverAuthor: PdfColor.fromHex('8D6E63'),
        cardBg: PdfColor.fromHex('FFFDFC'),
        cardBorder: PdfColor.fromHex('FFCCBC'),
        storyTitle: PdfColor.fromHex('4A2C2A'),
        body: PdfColor.fromHex('3E2723'),
        muted: PdfColor.fromHex('8D6E63'),
      );
    case 'classic':
    default:
      return _PdfExportTheme(
        coverBg: PdfColor.fromHex('FFF4FB'),
        coverBorder: PdfColor.fromHex('8E44AD'),
        coverTitle: PdfColor.fromHex('5C2D91'),
        coverAuthor: PdfColor.fromHex('555555'),
        cardBg: PdfColor.fromHex('FFF4FB'),
        cardBorder: PdfColor.fromHex('EADAE8'),
        storyTitle: PdfColor.fromHex('5C2D91'),
        body: PdfColor.fromHex('242124'),
        muted: PdfColor.fromHex('777777'),
      );
  }
}

class EbookPdfGenerator {
  /// Embedded TrueType fonts so curly quotes, apostrophes, dashes render (Helvetica lacks these glyphs).
  static Future<pw.ThemeData?> _loadPdfEmbeddedFontTheme() async {
    try {
      final fonts = await Future.wait([
        PdfGoogleFonts.openSansRegular(),
        PdfGoogleFonts.openSansBold(),
        PdfGoogleFonts.openSansItalic(),
        PdfGoogleFonts.openSansBoldItalic(),
      ]);
      return pw.ThemeData.withFont(
        base: fonts[0],
        bold: fonts[1],
        italic: fonts[2],
        boldItalic: fonts[3],
      );
    } catch (_) {
      return null;
    }
  }

  /// Fallback when fonts cannot load (offline): map Unicode punctuation to ASCII.
  static String _pdfAsciiPunctuationFallback(String input) {
    final sb = StringBuffer();
    for (final unit in input.runes) {
      switch (unit) {
        case 0x2018: // ‘
        case 0x2019: // ’
        case 0x02BC: // ʼ modifier letter apostrophe
          sb.write("'");
          break;
        case 0x201C: // “
        case 0x201D: // ”
          sb.write('"');
          break;
        case 0x2013: // –
          sb.write('-');
          break;
        case 0x2014: // —
          sb.write('--');
          break;
        case 0x2026: // …
          sb.write('...');
          break;
        case 0x00A0: // nbsp
          sb.write(' ');
          break;
        default:
          sb.writeCharCode(unit);
      }
    }
    return sb.toString();
  }

  /// Cover as its own page; story text + images flow across PDF pages like a book.
  static Future<Uint8List> buildPdf(
    Ebook ebook,
    List<StoryBookItem> stories,
  ) async {
    final embeddedFontTheme = await _loadPdfEmbeddedFontTheme();
    final pdfFontsOk = embeddedFontTheme != null;
    String pdfTxt(String raw) =>
        pdfFontsOk ? raw : _pdfAsciiPunctuationFallback(raw);

    final document = pw.Document(
      theme: embeddedFontTheme,
      title: ebook.title,
      author: ebook.authorName,
    );
    final pdfTheme = _pdfExportThemeFor(ebook.templateId);
    final cache = <String, pw.ImageProvider>{};
    final format = _EbookPdfLayout.pageFormat;
    final contentW = _EbookPdfLayout.contentWidthPt(format);

    Future<pw.ImageProvider?> loadUrl(String? url) async {
      if (url == null || url.isEmpty) return null;
      try {
        return cache[url] ??= await networkImage(url);
      } catch (_) {
        return null;
      }
    }

    final urls = <String>{};
    final ci = ebook.coverImage;
    if (ci != null && ci.isNotEmpty) urls.add(ci);
    for (final s in stories) {
      final cu = s.coverUrl;
      if (cu != null && cu.isNotEmpty) urls.add(cu);
      for (final b in ebookStoryBlocks(s)) {
        if (b['type'] == StoryContentCodec.typeImage) {
          final u = (b['url'] as String?)?.trim();
          if (u != null && u.isNotEmpty) urls.add(u);
        }
      }
    }
    for (final u in urls) {
      await loadUrl(u);
    }

    final ebookCoverProvider = await loadUrl(ebook.coverImage);

    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(_EbookPdfLayout.marginPt),
        build: (context) => _buildPdfCoverPage(
          ebook,
          ebookCoverProvider,
          pdfTheme,
          contentW,
          format,
          pdfTxt,
        ),
      ),
    );

    // One MultiPage per story so each chapter begins on a new PDF page (after the cover).
    for (final story in stories) {
      final chapterWidgets = _buildPdfChapterWidgets(
        story,
        pdfTheme,
        cache,
        contentW,
        format,
        pdfTxt,
      );
      if (chapterWidgets.isEmpty) continue;
      document.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: pw.EdgeInsets.all(_EbookPdfLayout.marginPt),
          build: (context) => chapterWidgets,
        ),
      );
    }

    return document.save();
  }

  static String safeFileName(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'pixiepen_ebook' : cleaned;
  }

  /// MultiPage splits between widgets; one huge [pw.Text] can exceed a sheet — chunk instead.
  static const int _kPdfTextChunkChars = 900;

  /// Prefer breaks at spaces so punctuation stays attached to words (no stray commas/periods).
  static int _findPdfChunkBreak(String rest, int max) {
    if (rest.length <= max) return rest.length;
    var cut = rest.lastIndexOf(' ', max);
    if (cut >= 12) return cut;
    // No space in first segment — extend to next space so we never split mid-word / mid-punctuation.
    final nextSpace = rest.indexOf(' ', max);
    if (nextSpace > 0) return nextSpace;
    return rest.length;
  }

  static List<String> _splitTextForMultiPage(String paragraph) {
    final t = paragraph.trim();
    if (t.isEmpty) return const [];
    if (t.length <= _kPdfTextChunkChars) return [t];
    final out = <String>[];
    var rest = t;
    while (rest.isNotEmpty) {
      if (rest.length <= _kPdfTextChunkChars) {
        out.add(rest.trim());
        break;
      }
      var cut = _findPdfChunkBreak(rest, _kPdfTextChunkChars);
      if (cut <= 0 || cut > rest.length) {
        cut = math.min(rest.length, _kPdfTextChunkChars);
      }
      final piece = rest.substring(0, cut).trim();
      if (piece.isNotEmpty) out.add(piece);
      rest = rest.substring(cut).trim();
    }
    return _mergeTrailingPunctuationChunks(out);
  }

  /// Join tiny leftover fragments like lone "." or "," with the previous chunk.
  static List<String> _mergeTrailingPunctuationChunks(List<String> chunks) {
    if (chunks.length < 2) return chunks;
    final merged = <String>[chunks.first];
    for (var i = 1; i < chunks.length; i++) {
      final c = chunks[i].trim();
      if (c.isEmpty) continue;
      if (RegExp(r'^[.,;:!?…]+$').hasMatch(c) && merged.isNotEmpty) {
        merged[merged.length - 1] = '${merged.last}$c';
      } else {
        merged.add(chunks[i]);
      }
    }
    return merged;
  }

  static pw.Widget _buildPdfCoverPage(
    Ebook ebook,
    pw.ImageProvider? image,
    _PdfExportTheme theme,
    double contentWidth,
    PdfPageFormat format,
    String Function(String) pdfTxt,
  ) {
    final maxArtH = _EbookPdfLayout.maxBookCoverArtHeightPt(format);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: theme.coverBg,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: theme.coverBorder, width: 2),
      ),
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (image != null) ...[
            pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.SizedBox(
                width: contentWidth,
                height: maxArtH,
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            ),
            pw.SizedBox(height: 22),
          ],
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt(ebook.title),
              textAlign: pw.TextAlign.center,
              maxLines: 4,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: theme.coverTitle,
                height: 1.2,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt('by ${ebook.authorName}'),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 16,
                color: theme.coverAuthor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildPdfChapterWidgets(
    StoryBookItem story,
    _PdfExportTheme theme,
    Map<String, pw.ImageProvider> cache,
    double contentWidth,
    PdfPageFormat format,
    String Function(String) pdfTxt,
  ) {
    final maxChapterCoverH = _EbookPdfLayout.maxChapterCoverHeightPt(format);
    final maxInlineH = _EbookPdfLayout.maxInlineImageHeightPt(format);

    final out = <pw.Widget>[
      pw.Container(
        width: contentWidth,
        child: pw.Text(
          pdfTxt(story.title),
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: theme.storyTitle,
            height: 1.25,
          ),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        width: contentWidth,
        child: pw.Text(
          pdfTxt('by ${story.authorName}'),
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 12,
            color: theme.muted,
            height: 1.35,
          ),
        ),
      ),
    ];

    final coverUrl = story.coverUrl?.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final prov = cache[coverUrl];
      if (prov != null) {
        out.add(pw.SizedBox(height: 14));
        out.add(
          pw.ClipRRect(
            horizontalRadius: 12,
            verticalRadius: 12,
            child: pw.SizedBox(
              width: contentWidth,
              height: maxChapterCoverH,
              child: pw.Center(
                child: pw.Image(prov, fit: pw.BoxFit.contain),
              ),
            ),
          ),
        );
      }
    }

    final blocks = ebookStoryBlocks(story);
    var anyBody = false;
    for (final block in blocks) {
      final type = block['type'] as String?;
      if (type == StoryContentCodec.typeImage) {
        final u = (block['url'] as String?)?.trim();
        if (u == null || u.isEmpty) continue;
        final prov = cache[u];
        if (prov == null) continue;
        anyBody = true;
        out.add(pw.SizedBox(height: 12));
        out.add(
          pw.Center(
            child: pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.ConstrainedBox(
                constraints: pw.BoxConstraints(
                  maxWidth: contentWidth,
                  maxHeight: maxInlineH,
                ),
                child: pw.Image(prov, fit: pw.BoxFit.contain),
              ),
            ),
          ),
        );
      } else {
        final raw = (block['text'] as String?) ?? '';
        if (raw.trim().isEmpty) continue;
        anyBody = true;
        for (final para in raw.split(RegExp(r'\n\s*\n'))) {
          final p = para.trim();
          if (p.isEmpty) continue;
          for (final chunk in _splitTextForMultiPage(p)) {
            out.add(pw.SizedBox(height: 10));
            out.add(
              pw.Container(
                width: contentWidth,
                child: pw.Text(
                  pdfTxt(chunk),
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontSize: 12.5,
                    height: 1.65,
                    letterSpacing: 0.15,
                    color: theme.body,
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (!anyBody && (coverUrl == null || coverUrl.isEmpty)) {
      out.add(pw.SizedBox(height: 12));
      out.add(
        pw.Container(
          width: contentWidth,
          child: pw.Text(
            pdfTxt('(This story is empty.)'),
            style: pw.TextStyle(fontSize: 13, color: theme.muted),
          ),
        ),
      );
    }

    return out;
  }
}

class Ebook {
  final String ebookId;
  final String userId;
  final String title;
  final String authorName;
  final String? coverImage;
  final List<String> storyIds;
  final DateTime createdAt;
  final String templateId;

  const Ebook({
    required this.ebookId,
    required this.userId,
    required this.title,
    required this.authorName,
    required this.coverImage,
    required this.storyIds,
    required this.createdAt,
    this.templateId = 'classic',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ebookId': ebookId,
      'userId': userId,
      'title': title,
      'authorName': authorName,
      'coverImage': coverImage,
      'storyIds': storyIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'templateId': templateId,
    };
  }

  static Ebook fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = data['createdAt'];
    final storyIds = data['storyIds'];

    return Ebook(
      ebookId: (data['ebookId'] as String?) ?? doc.id,
      userId: (data['userId'] as String?) ?? '',
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Untitled E-Book',
      authorName: (data['authorName'] as String?) ?? 'PixiePen Author',
      coverImage: data['coverImage'] as String?,
      storyIds: storyIds is List
          ? storyIds.whereType<String>().toList()
          : const <String>[],
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      templateId: (data['templateId'] as String?)?.trim().isNotEmpty == true
          ? (data['templateId'] as String).trim()
          : 'classic',
    );
  }
}

class StoryBookItem {
  final String id;
  final String title;
  final String body;
  /// Ordered text + image blocks from Firestore (`content`); drives eBook layout.
  final List<Map<String, dynamic>>? content;
  final String authorName;
  final String? coverUrl;
  final DateTime createdAt;
  final String status;
  final String? approvalStatus;

  const StoryBookItem({
    required this.id,
    required this.title,
    required this.body,
    this.content,
    required this.authorName,
    required this.coverUrl,
    required this.createdAt,
    this.status = 'draft',
    this.approvalStatus,
  });

  String get preview {
    final trimmed = body.trim();
    if (trimmed.length <= 120) return trimmed;
    return '${trimmed.substring(0, 120)}...';
  }

  static StoryBookItem fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = data['createdAt'];

    return StoryBookItem(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Untitled Story',
      body: (data['body'] as String?) ?? '',
      content: StoryContentCodec.parseContent(data['content']),
      authorName: (data['authorName'] as String?) ?? 'PixiePen Author',
      coverUrl: data['coverUrl'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      status: (data['status'] as String?) ?? 'draft',
      approvalStatus: data['approvalStatus'] as String?,
    );
  }
}

class EbookPageData {
  final Ebook? ebook;
  final StoryBookItem? story;

  const EbookPageData._({this.ebook, this.story});

  factory EbookPageData.cover(Ebook ebook) => EbookPageData._(ebook: ebook);

  factory EbookPageData.chapter(StoryBookItem story) =>
      EbookPageData._(story: story);

  bool get isCover => ebook != null;
}

/// Book cover, then one horizontal page per story (each story scrolls internally).
List<EbookPageData> buildEbookPages(Ebook ebook, List<StoryBookItem> stories) {
  return [
    EbookPageData.cover(ebook),
    for (final s in stories) EbookPageData.chapter(s),
  ];
}

/// Same ordered blocks as the write screen / Firestore `content` field.
List<Map<String, dynamic>> ebookStoryBlocks(StoryBookItem story) {
  final c = story.content;
  if (c != null && c.isNotEmpty) return c;
  return [StoryContentCodec.textBlock(story.body)];
}
