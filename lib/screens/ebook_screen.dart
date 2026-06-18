import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixiepen/screens/community.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts, networkImage;

import 'theme.dart';
import '../services/story_image_generation_service.dart';
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

/// Body text style for the in-app reader.
///
/// Defaults to a book serif (Literata) for that "real book" feel; the user
/// can override via the reader settings sheet.
TextStyle _ebookReaderBody(
  EbookTemplateDef t, {
  bool? useSerif,
  double fontScale = 1.0,
  double lineHeight = 1.7,
}) {
  final bool isSerif = useSerif ?? true;
  final base = TextStyle(
    fontSize: t.readerBodySize * fontScale,
    height: lineHeight,
    color: t.readerBodyColor,
    letterSpacing: 0.1,
  );
  if (isSerif) return GoogleFonts.literata(textStyle: base);
  return GoogleFonts.plusJakartaSans(textStyle: base);
}

/// "Paragraph" containing only `***`, `---`, `~~~`, `✦ ✦ ✦` etc.
/// renders as a decorative scene-break ornament instead of literal text.
final RegExp _kSceneBreakLine = RegExp(
  r'^\s*(?:[*]\s*){3,}\s*$'
  r'|^\s*(?:[-]\s*){3,}\s*$'
  r'|^\s*(?:[~]\s*){3,}\s*$'
  r'|^\s*(?:[✦●•]\s*){2,}\s*$',
);

bool _isSceneBreakLine(String paragraph) =>
    _kSceneBreakLine.hasMatch(paragraph.trim());

/// Centered glyph row used for scene breaks and the end-of-chapter ornament.
class _ChapterOrnament extends StatelessWidget {
  final Color color;
  final String glyph;
  final double size;
  final EdgeInsetsGeometry padding;

  const _ChapterOrnament({
    required this.color,
    this.glyph = '★  ★  ★',
    this.size = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        glyph,
        textAlign: TextAlign.center,
        style: GoogleFonts.literata(
          fontSize: size,
          color: color,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Subtle 3-D "page flip" applied to each [PageView] child based on its
/// distance from the focused page. Gives the swipe a book-y feel without
/// pulling in a new package.
class _PageFlipEffect extends StatelessWidget {
  final double pageOffset;
  final Widget child;

  const _PageFlipEffect({required this.pageOffset, required this.child});

  @override
  Widget build(BuildContext context) {
    final double t = pageOffset.clamp(-1.0, 1.0);
    final double absT = t.abs();
    // The off-screen edge is the "hinge" — pages curl from the side they're
    // sliding away from.
    final Alignment hinge =
        t < 0 ? Alignment.centerRight : Alignment.centerLeft;
    final double rotY = t * 0.35; // ~20° at the extreme — subtle.
    final double scale = 1.0 - absT * 0.04;

    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateY(rotY)
      ..scale(scale);

    return Transform(
      alignment: hinge,
      transform: m,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (absT > 0.04)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: t < 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: t < 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: absT * 0.22),
                        Colors.black.withValues(alpha: 0),
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

/// Small two-option pill toggle used in the reader settings sheet.
class _SegToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool isLeft;
  final Color accent;
  final EbookTemplateDef template;
  final ValueChanged<bool> onChanged;

  const _SegToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeft,
    required this.accent,
    required this.template,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : template.readerStoryTitleColor,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: template.readerCardBorder.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          option(leftLabel, isLeft, () => onChanged(true)),
          option(rightLabel, !isLeft, () => onChanged(false)),
        ],
      ),
    );
  }
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
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const CommunityScreen(),
            ),
          );
        },
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
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
  final StoryImageGenerationService _imageGen = StoryImageGenerationService();

  String _selectedTemplateId = 'classic';
  List<StoryBookItem> _selectedStories = [];
  bool _isCreating = false;

  // AI book cover preview (overrides "first story's cover" when set).
  String? _aiCoverUrl;
  Uint8List? _aiCoverBytes;
  bool _isGeneratingCover = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    final existing = widget.editing;
    if (existing != null) {
      _titleController.text = existing.title;
      _selectedTemplateId = existing.templateId;
      // Pre-fill the cover preview with whatever was saved last time so the
      // editor shows the current book cover and the user can replace it.
      final savedCover = existing.coverImage?.trim();
      if (savedCover != null && savedCover.isNotEmpty) {
        _aiCoverUrl = savedCover;
      }
      _loadStoriesForEdit(existing);
    }
  }

  void _onTitleChanged() {
    // Title is shown live on the AI-cover card preview, so trigger a rebuild
    // whenever it changes (no-op if a frame is already pending).
    if (mounted) setState(() {});
  }

  Future<void> _generateAiCover() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a book title before generating a cover.'),
        ),
      );
      return;
    }
    if (_isGeneratingCover) return;

    setState(() => _isGeneratingCover = true);
    try {
      // Pull a few story titles + opening lines to bias the cover toward the
      // book's actual content (themes, characters, mood).
      final storyTitles = _selectedStories
          .take(3)
          .map((s) => s.title.trim())
          .where((t) => t.isNotEmpty)
          .join(', ');
      final firstSnippet = _selectedStories.isNotEmpty
          ? _selectedStories.first.preview.trim()
          : '';

      final buf = StringBuffer()
        ..write("Children's book cover illustration for an anthology titled \"")
        ..write(title)
        ..write('".');
      if (storyTitles.isNotEmpty) {
        buf
          ..write(' Themes from inside the book: ')
          ..write(storyTitles)
          ..write('.');
      }
      if (firstSnippet.isNotEmpty) {
        buf
          ..write(' Opening scene mood: ')
          ..write(firstSnippet)
          ..write('.');
      }
      buf.write(
        ' Whimsical magical watercolor storybook illustration style with '
        'soft warm lighting, colorful and cheerful, portrait orientation '
        'suitable as a book cover. STRICTLY no text, letters, words, '
        'numbers, signatures, captions, or watermarks anywhere in the '
        'image — pure illustration only. Age-appropriate for children '
        'ages 9-12.',
      );

      final images = await _imageGen.generateImages(buf.toString(), count: 1);
      if (!mounted) return;
      if (images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cover was generated. Try again.')),
        );
        return;
      }
      final first = images.first;
      if (first.url.trim().isEmpty) return;
      setState(() {
        _aiCoverUrl = first.url;
        _aiCoverBytes = first.bytes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book cover generated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate cover: $error')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingCover = false);
    }
  }

  void _clearAiCover() {
    setState(() {
      _aiCoverUrl = null;
      _aiCoverBytes = null;
    });
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
    _titleController.removeListener(_onTitleChanged);
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
      // AI-generated book cover wins; falls back to the first story's cover
      // when the user didn't generate one.
      final aiCover = _aiCoverUrl?.trim();
      final coverImage = (aiCover != null && aiCover.isNotEmpty)
          ? aiCover
          : _selectedStories
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
              initialCoverBytes: _aiCoverBytes,
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
            initialCoverBytes: _aiCoverBytes,
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
          const SizedBox(height: 18),
          _AiBookCoverCard(
            coverUrl: _aiCoverUrl,
            coverBytes: _aiCoverBytes,
            title: _titleController.text.trim(),
            isGenerating: _isGeneratingCover,
            onGenerate: _generateAiCover,
            onClear: _clearAiCover,
          ),
          if (_selectedStories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stories in this book',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _kEbookTitleColor,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
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

  /// Optional in-memory bytes for [Ebook.coverImage] — passed through right
  /// after generation/save so the cover paints instantly without waiting for
  /// a (possibly CORS-blocked, on web) network fetch of the URL.
  final Uint8List? initialCoverBytes;

  const EbookReaderScreen({
    super.key,
    required this.ebook,
    required this.stories,
    this.initialCoverBytes,
  });

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  late final PageController _pageController;
  late final List<EbookPageData> _pages;
  int _currentPage = 0;
  bool _isExporting = false;

  // Reader preferences (in-memory only).
  bool _useSerifFont = true;
  double _fontScale = 1.0;
  double _lineHeight = 1.7;
  String? _activeTemplateId;

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

  void _jumpToChapter(int chapterOneBased) {
    final tocIndex = _pages.indexWhere((p) => p.isToc);
    final target = tocIndex < 0 ? chapterOneBased : tocIndex + chapterOneBased;
    final clamped = target.clamp(0, _pages.length - 1);
    _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _openReadingSettings(EbookTemplateDef currentTemplate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, sheetSetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.62,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scroll) {
                return Container(
                  decoration: BoxDecoration(
                    color: currentTemplate.readerCardBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: currentTemplate.readerCardBorder,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reading Settings',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.literata(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: currentTemplate.readerStoryTitleColor,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _settingsLabel('Font Family', currentTemplate),
                      const SizedBox(height: 8),
                      _SegToggle(
                        leftLabel: 'Serif (Book)',
                        rightLabel: 'Sans (App)',
                        isLeft: _useSerifFont,
                        accent: kAppPrimary,
                        template: currentTemplate,
                        onChanged: (left) {
                          sheetSetState(() {});
                          setState(() => _useSerifFont = left);
                        },
                      ),
                      const SizedBox(height: 22),
                      _settingsLabel(
                        'Font Size  ·  ${(_fontScale * 100).round()}%',
                        currentTemplate,
                      ),
                      Slider(
                        value: _fontScale,
                        min: 0.85,
                        max: 1.35,
                        divisions: 10,
                        activeColor: kAppPrimary,
                        onChanged: (v) {
                          sheetSetState(() {});
                          setState(() => _fontScale = v);
                        },
                      ),
                      const SizedBox(height: 6),
                      _settingsLabel(
                        'Line Spacing  ·  ${_lineHeight.toStringAsFixed(2)}',
                        currentTemplate,
                      ),
                      Slider(
                        value: _lineHeight,
                        min: 1.45,
                        max: 1.95,
                        divisions: 10,
                        activeColor: kAppPrimary,
                        onChanged: (v) {
                          sheetSetState(() {});
                          setState(() => _lineHeight = v);
                        },
                      ),
                      const SizedBox(height: 18),
                      _settingsLabel('Theme', currentTemplate),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 132,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: EbookTemplateCatalog.all.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final t = EbookTemplateCatalog.all[i];
                            final id =
                                _activeTemplateId ?? widget.ebook.templateId;
                            final selected = t.id == id;
                            return _TemplateChoiceCard(
                              template: t,
                              selected: selected,
                              onTap: () {
                                sheetSetState(() {});
                                setState(() => _activeTemplateId = t.id);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _settingsLabel(String text, EbookTemplateDef t) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: t.readerPartLabelColor,
      ),
    );
  }

  Widget _buildReaderPage(
    EbookPageData page,
    EbookTemplateDef template,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: page.isCover
          ? _BookCoverPage(
              ebook: page.ebook!,
              stories: widget.stories,
              template: template,
              initialBytes: widget.initialCoverBytes,
            )
          : page.isToc
              ? _TocPage(
                  stories: page.tocStories!,
                  template: template,
                  onJumpTo: _jumpToChapter,
                )
              : _StoryChapterPage(
                  story: page.story!,
                  chapterIndex: page.chapterIndex,
                  template: template,
                  useSerif: _useSerifFont,
                  fontScale: _fontScale,
                  lineHeight: _lineHeight,
                  pageOrdinal: index + 1,
                  totalPages: _pages.length,
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final template = EbookTemplateCatalog.byId(
      _activeTemplateId ?? widget.ebook.templateId,
    );

    return Scaffold(
      backgroundColor: template.readerScaffoldBg,
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.ebook.title,
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Reading settings',
            onPressed: () => _openReadingSettings(template),
            icon: const Icon(Icons.tune, color: Colors.white),
          ),
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
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double offset = 0;
                        if (_pageController.position.haveDimensions) {
                          offset = (_pageController.page ??
                                  index.toDouble()) -
                              index;
                        }
                        return _PageFlipEffect(
                          pageOffset: offset,
                          child: child!,
                        );
                      },
                      child: _buildReaderPage(_pages[index], template, index),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _pages.length,
                        minHeight: 6,
                        color: kAppPrimary,
                        backgroundColor: template.readerCardBorder
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentPage + 1} / ${_pages.length}',
                      style: GoogleFonts.literata(
                        fontSize: 12,
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

class _AiBookCoverCard extends StatelessWidget {
  final String? coverUrl;
  final Uint8List? coverBytes;
  final String title;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onClear;

  const _AiBookCoverCard({
    required this.coverUrl,
    required this.coverBytes,
    required this.title,
    required this.isGenerating,
    required this.onGenerate,
    required this.onClear,
  });

  bool get _hasCover {
    final url = coverUrl?.trim();
    return (url != null && url.isNotEmpty) ||
        (coverBytes != null && coverBytes!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = !isGenerating && title.isNotEmpty;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAppPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: kAppPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI book cover',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kEbookTitleColor,
                  ),
                ),
              ),
              if (_hasCover)
                TextButton.icon(
                  onPressed: isGenerating ? null : onClear,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: _kEbookMutedText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hasCover
                ? 'Tap "Regenerate" to try a new look.'
                : 'Generate a beautiful cover image for the whole eBook from '
                    'your title and stories.',
            style: TextStyle(
              fontSize: 12.5,
              color: _kEbookMutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_hasCover)
                    _CoverPreviewImage(
                      url: coverUrl,
                      bytes: coverBytes,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            kAppPrimary.withValues(alpha: 0.18),
                            kAppPrimary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          title.isEmpty
                              ? 'Your book cover will appear here'
                              : title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.literata(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kEbookTitleColor,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  if (_hasCover && title.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 36, 16, 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.literata(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4,
                                color: Color(0xCC000000),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isGenerating)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Painting your cover…',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canGenerate ? onGenerate : null,
              icon: Icon(
                _hasCover ? Icons.refresh : Icons.auto_awesome,
                size: 18,
              ),
              label: Text(
                _hasCover ? 'Regenerate cover' : 'Generate cover with AI',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders an AI-generated cover preview. Uses raw bytes when available
/// (fast first-paint after generation) and falls back to the storage URL
/// (CORS-safe via [StorageImage]).
class _CoverPreviewImage extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;

  const _CoverPreviewImage({required this.url, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final hasBytes = bytes != null && bytes!.isNotEmpty;
    if (hasBytes) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return StorageImage(
      url: url,
      fit: BoxFit.cover,
      placeholder: Container(color: kAppPrimary.withValues(alpha: 0.08)),
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
  final List<StoryBookItem> stories;
  final EbookTemplateDef template;

  /// Optional in-memory cover bytes — when provided (right after AI
  /// generation), they paint instantly and we skip the URL fetch.
  final Uint8List? initialBytes;

  const _BookCoverPage({
    required this.ebook,
    required this.stories,
    required this.template,
    this.initialBytes,
  });

  bool get _hasCoverImage =>
      (initialBytes != null && initialBytes!.isNotEmpty) ||
      (ebook.coverImage != null && ebook.coverImage!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    // When a cover image exists (AI-generated or from a story), render a
    // real book-cover with the artwork edge-to-edge and the title/byline
    // overlaid on top (Path B — AI paints art, app overlays text).
    // Otherwise fall back to the ornamental text-only cover.
    if (_hasCoverImage) {
      return _buildOverlayCover(context);
    }
    return _buildOrnamentalCover(context);
  }

  // -- Variant 1: edge-to-edge image with overlaid title (AI cover style) --
  Widget _buildOverlayCover(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: template.coverBorder, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StorageImage(
              url: ebook.coverImage,
              bytes: initialBytes,
              fit: BoxFit.cover,
              placeholder: Container(color: template.coverBorder),
            ),
            // Top tagline strip with subtle scrim so it reads on any photo.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Text(
                  'A  P I X I E P E N  C O L L E C T I O N',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
            // Bottom dark gradient + title block.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 80, 22, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sparkle divider on the dark scrim.
                    Text(
                      '★  ★  ★',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ebook.title,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 8,
                            color: Color(0xCC000000),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'by ${ebook.authorName}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.literata(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    if (stories.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${stories.length} ${stories.length == 1 ? 'Story' : 'Stories'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Variant 2: text-only ornamental cover (no image available) --
  Widget _buildOrnamentalCover(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: template.coverGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: template.coverBorder, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top ornamental rule
              Row(children: [
                Expanded(
                  child: Divider(
                    color: template.coverBorder,
                    thickness: 1.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.auto_stories,
                    color: template.coverBorder,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: template.coverBorder,
                    thickness: 1.5,
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              Text(
                ebook.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: template.coverTitleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'by ${ebook.authorName}',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: template.coverAuthorColor,
                ),
              ),
              const SizedBox(height: 20),
              // Mid ornamental rule
              Row(children: [
                Expanded(
                  child: Divider(color: template.coverBorder, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '★  ★  ★',
                    style: TextStyle(
                      color: template.coverBorder,
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: template.coverBorder, thickness: 1),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                'A  P I X I E P E N  C O L L E C T I O N',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  letterSpacing: 3.5,
                  fontWeight: FontWeight.w700,
                  color: template.coverAuthorColor,
                ),
              ),
              if (stories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: template.coverBorder.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: template.coverBorder.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${stories.length} ${stories.length == 1 ? 'Story' : 'Stories'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: template.coverAuthorColor,
                    ),
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

/// In-app Table of Contents page (appears between cover and first chapter
/// when the book has 2+ stories).
class _TocPage extends StatelessWidget {
  final List<StoryBookItem> stories;
  final EbookTemplateDef template;
  final void Function(int chapterOneBased) onJumpTo;

  const _TocPage({
    required this.stories,
    required this.template,
    required this.onJumpTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: template.readerCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: template.readerCardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            template.readerCardBg,
            Color.alphaBlend(
              template.readerCardBorder.withValues(alpha: 0.16),
              template.readerCardBg,
            ),
          ],
          stops: const [0.55, 1.0],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'C O N T E N T S',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: template.readerPartLabelColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Table of Contents',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: template.readerStoryTitleColor,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Divider(
                color: template.readerCardBorder,
                thickness: 1.6,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.menu_book,
                color: template.readerPartLabelColor,
                size: 16,
              ),
            ),
            Expanded(
              child: Divider(
                color: template.readerCardBorder,
                thickness: 1.6,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: stories.length,
              separatorBuilder: (_, __) => Divider(
                color: template.readerCardBorder,
                thickness: 0.7,
                height: 1,
                indent: 12,
                endIndent: 12,
              ),
              itemBuilder: (context, i) {
                final story = stories[i];
                return InkWell(
                  onTap: () => onJumpTo(i + 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kAppPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kAppPrimary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.literata(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kAppPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            story.title,
                            style: GoogleFonts.literata(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: template.readerStoryTitleColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: template.readerPartLabelColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One swipe per story: chapter header, optional cover, drop-capped body that
/// scrolls internally — styled to feel like a printed book chapter.
class _StoryChapterPage extends StatelessWidget {
  final StoryBookItem story;
  final EbookTemplateDef template;
  final int chapterIndex; // 1-based; 0 hides the "Chapter N" label.
  final bool useSerif;
  final double fontScale;
  final double lineHeight;
  final int pageOrdinal;
  final int totalPages;

  const _StoryChapterPage({
    required this.story,
    required this.template,
    this.chapterIndex = 0,
    this.useSerif = true,
    this.fontScale = 1.0,
    this.lineHeight = 1.7,
    this.pageOrdinal = 0,
    this.totalPages = 0,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = ebookStoryBlocks(story);
    final bodyStyle = _ebookReaderBody(
      template,
      useSerif: useSerif,
      fontScale: fontScale,
      lineHeight: lineHeight,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: template.readerCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: template.readerCardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        // Subtle paper vignette so the card reads like a page, not a UI tile.
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            template.readerCardBg,
            Color.alphaBlend(
              template.readerCardBorder.withValues(alpha: 0.18),
              template.readerCardBg,
            ),
          ],
          stops: const [0.55, 1.0],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentW = constraints.maxWidth - 36; // account for padding
          final maxChapterCoverH = math.min(220.0, contentW * 0.52);
          final maxInlineImageH = math.min(320.0, contentW * 0.78);

          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chapterIndex > 0) ...[
                  Text(
                    'C H A P T E R   $chapterIndex',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: template.readerPartLabelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  story.title,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 26,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                    color: template.readerStoryTitleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'by ${story.authorName}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: template.readerPartLabelColor,
                  ),
                ),
                // Option B: heading → cover image → ✦ divider → body.
                // The cover sits directly under the title/byline (like a
                // magazine chapter opener), then a delicate ✦ divider
                // introduces the body text.
                if (story.coverUrl != null && story.coverUrl!.isNotEmpty) ...[
                  const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Divider(
                      color: template.readerCardBorder,
                      thickness: 1.2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '★',
                      style: TextStyle(
                        color: template.readerPartLabelColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: template.readerCardBorder,
                      thickness: 1.2,
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildChapterBody(
                      blocks,
                      bodyStyle,
                      contentW,
                      maxInlineImageH,
                    ),
                  ),
                ),
                if (pageOrdinal > 0 && totalPages > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '— $pageOrdinal —',
                        style: GoogleFonts.literata(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: template.readerPartLabelColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChapterBody(
    List<Map<String, dynamic>> blocks,
    TextStyle bodyStyle,
    double contentW,
    double maxInlineH,
  ) {
    if (_chapterBodyIsEmpty(blocks)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '(This story is empty.)',
          style: bodyStyle,
          textAlign: TextAlign.center,
        ),
      );
    }

    final children = <Widget>[];
    var dropCapApplied = false;

    for (final block in blocks) {
      final type = block['type'] as String?;
      if (type == StoryContentCodec.typeImage) {
        final url = (block['url'] as String?)?.trim();
        if (url == null || url.isEmpty) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: contentW,
                  maxHeight: maxInlineH,
                ),
                child: StorageImage(
                  url: url,
                  width: contentW,
                  fit: BoxFit.contain,
                  placeholder: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final raw = (block['text'] as String?) ?? '';
      if (raw.trim().isEmpty) continue;

      final paragraphs = raw.split(RegExp(r'\n\s*\n'));
      for (final para in paragraphs) {
        final p = para.trim();
        if (p.isEmpty) continue;

        if (_isSceneBreakLine(p)) {
          children.add(
            _ChapterOrnament(color: template.readerPartLabelColor),
          );
          continue;
        }

        if (!dropCapApplied) {
          dropCapApplied = true;
          children.add(_buildDropCapParagraph(p, bodyStyle));
        } else {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                p,
                style: bodyStyle,
                textAlign: TextAlign.justify,
              ),
            ),
          );
        }
      }
    }

    if (children.isNotEmpty) {
      children.add(
        _ChapterOrnament(
          color: template.readerPartLabelColor,
          glyph: '— ★ —',
          size: 18,
          padding: const EdgeInsets.only(top: 12, bottom: 6),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildDropCapParagraph(String paragraph, TextStyle bodyStyle) {
    final firstChar = paragraph.substring(0, 1);
    final rest = paragraph.length > 1 ? paragraph.substring(1) : '';

    final capStyle = GoogleFonts.literata(
      fontSize: (bodyStyle.fontSize ?? 18) * 3.0,
      fontWeight: FontWeight.w900,
      color: template.readerStoryTitleColor,
      height: 0.92,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: firstChar, style: capStyle),
            TextSpan(text: rest, style: bodyStyle),
          ],
        ),
        textAlign: TextAlign.justify,
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
  /// Embedded TrueType fonts so curly quotes, apostrophes, dashes render
  /// (Helvetica lacks these glyphs). Prefers Lora (book serif) for that
  /// printed-novel feel; falls back to Open Sans if Lora isn't available.
  static Future<pw.ThemeData?> _loadPdfEmbeddedFontTheme() async {
    // Loads Noto Color Emoji as a fallback so glyphs like ✨ 🌟 ❤️ don't
    // render as crosses (`pdf` can't draw emoji from Lora/Open Sans alone).
    // If the font can't be fetched (offline build), we accept "no emoji
    // fallback" as a safe no-op — emojis will still render as crosses but
    // the PDF will not fail to build.
    final pdfFontFallback = <pw.Font>[];
    try {
      pdfFontFallback.add(await PdfGoogleFonts.notoSansSymbols2Regular());
    } catch (_) {
      /* no symbol fallback available */
    }
    try {
      pdfFontFallback.add(await PdfGoogleFonts.notoColorEmoji());
    } catch (_) {
      /* no emoji fallback available */
    }

    try {
      final fonts = await Future.wait([
        PdfGoogleFonts.loraRegular(),
        PdfGoogleFonts.loraBold(),
        PdfGoogleFonts.loraItalic(),
        PdfGoogleFonts.loraBoldItalic(),
      ]);
      return pw.ThemeData.withFont(
        base: fonts[0],
        bold: fonts[1],
        italic: fonts[2],
        boldItalic: fonts[3],
        fontFallback: pdfFontFallback.isNotEmpty ? pdfFontFallback : null,
      );
    } catch (_) {
      // Fall back to Open Sans (universally available in `printing`).
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
          fontFallback: pdfFontFallback.isNotEmpty ? pdfFontFallback : null,
        );
      } catch (_) {
        return null;
      }
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
          stories.length,
        ),
      ),
    );

    // Table of Contents page (only useful with 2+ stories).
    if (stories.length >= 2) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(_EbookPdfLayout.marginPt),
          build: (context) =>
              _buildPdfTocPage(ebook, stories, pdfTheme, contentW, pdfTxt),
        ),
      );
    }

    // One MultiPage per story — each chapter starts on a new sheet and gets a
    // book-style page footer.
    for (var i = 0; i < stories.length; i++) {
      final story = stories[i];
      final chapterWidgets = _buildPdfChapterWidgets(
        story,
        i + 1,
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
          footer: (ctx) => _buildPdfFooter(
            ebook.title,
            ctx.pageNumber,
            pdfTheme,
            contentW,
            pdfTxt,
          ),
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
    int storyCount,
  ) {
    // When a cover image exists, paint the artwork edge-to-edge and overlay
    // the title and byline on a soft dark scrim — same look as the in-app
    // reader. Without an image, fall back to a typographic ornamental cover.
    if (image != null) {
      return _buildPdfOverlayCover(
        ebook,
        image,
        theme,
        contentWidth,
        format,
        pdfTxt,
        storyCount,
      );
    }
    return _buildPdfOrnamentalCover(
      ebook,
      theme,
      contentWidth,
      format,
      pdfTxt,
      storyCount,
    );
  }

  static pw.Widget _buildPdfOverlayCover(
    Ebook ebook,
    pw.ImageProvider image,
    _PdfExportTheme theme,
    double contentWidth,
    PdfPageFormat format,
    String Function(String) pdfTxt,
    int storyCount,
  ) {
    final innerH = _EbookPdfLayout.innerHeightPt(format);
    final coverH = math.min(innerH, contentWidth * 4 / 3);

    return pw.Container(
      width: contentWidth,
      height: coverH,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: theme.coverBorder, width: 2.5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 18,
        verticalRadius: 18,
        child: pw.Stack(
          children: [
            // Full-bleed cover art.
            pw.Positioned.fill(
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
            // Top tagline strip with subtle scrim.
            pw.Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(16, 22, 16, 40),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topCenter,
                    end: pw.Alignment.bottomCenter,
                    colors: [
                      PdfColor.fromInt(0x66000000),
                      PdfColor.fromInt(0x00000000),
                    ],
                  ),
                ),
                child: pw.Text(
                  pdfTxt('A  P I X I E P E N  C O L L E C T I O N'),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xF2FFFFFF),
                  ),
                ),
              ),
            ),
            // Bottom dark scrim + title block.
            pw.Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(22, 80, 22, 28),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topCenter,
                    end: pw.Alignment.bottomCenter,
                    colors: [
                      PdfColor.fromInt(0x00000000),
                      PdfColor.fromInt(0x8C000000),
                      PdfColor.fromInt(0xD1000000),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      '★  ★  ★',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xD9FFFFFF),
                        fontSize: 11,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      width: contentWidth - 44,
                      child: pw.Text(
                        pdfTxt(ebook.title),
                        textAlign: pw.TextAlign.center,
                        maxLines: 3,
                        overflow: pw.TextOverflow.clip,
                        style: pw.TextStyle(
                          fontSize: 30,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          height: 1.12,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      pdfTxt('by ${ebook.authorName}'),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColor.fromInt(0xF2FFFFFF),
                        height: 1.3,
                      ),
                    ),
                    if (storyCount > 0) ...[
                      pw.SizedBox(height: 14),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0x2DFFFFFF),
                          borderRadius: pw.BorderRadius.circular(22),
                          border: pw.Border.all(
                            color: PdfColor.fromInt(0xA0FFFFFF),
                            width: 1,
                          ),
                        ),
                        child: pw.Text(
                          pdfTxt(
                            '$storyCount ${storyCount == 1 ? 'Story' : 'Stories'}',
                          ),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xF2FFFFFF),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfOrnamentalCover(
    Ebook ebook,
    _PdfExportTheme theme,
    double contentWidth,
    PdfPageFormat format,
    String Function(String) pdfTxt,
    int storyCount,
  ) {
    final innerH = _EbookPdfLayout.innerHeightPt(format);

    return pw.Container(
      width: contentWidth,
      height: innerH,
      decoration: pw.BoxDecoration(
        color: theme.coverBg,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: theme.coverBorder, width: 2.5),
      ),
      padding: const pw.EdgeInsets.fromLTRB(30, 36, 30, 32),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // Top ornament: rule — sparkle — rule.
          pw.Row(children: [
            pw.Expanded(
              child:
                  pw.Divider(color: theme.coverBorder, thickness: 1.5),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              '★',
              style: pw.TextStyle(color: theme.coverBorder, fontSize: 14),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child:
                  pw.Divider(color: theme.coverBorder, thickness: 1.5),
            ),
          ]),
          pw.SizedBox(height: 28),
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt(ebook.title),
              textAlign: pw.TextAlign.center,
              maxLines: 4,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: theme.coverTitle,
                height: 1.18,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt('by ${ebook.authorName}'),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 16,
                fontStyle: pw.FontStyle.italic,
                color: theme.coverAuthor,
                height: 1.3,
              ),
            ),
          ),
          pw.SizedBox(height: 22),
          // Mid ornament: rule — three sparkles — rule.
          pw.Row(children: [
            pw.Expanded(
              child: pw.Divider(color: theme.coverBorder, thickness: 1),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              '★  ★  ★',
              style: pw.TextStyle(color: theme.coverBorder, fontSize: 10),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Divider(color: theme.coverBorder, thickness: 1),
            ),
          ]),
          pw.SizedBox(height: 16),
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt('A  P I X I E P E N  C O L L E C T I O N'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 9,
                letterSpacing: 3,
                color: theme.muted,
                height: 1.4,
              ),
            ),
          ),
          if (storyCount > 0) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: theme.coverBorder.shade(160),
                borderRadius: pw.BorderRadius.circular(20),
                border: pw.Border.all(color: theme.coverBorder, width: 0.6),
              ),
              child: pw.Text(
                pdfTxt(
                  '$storyCount ${storyCount == 1 ? 'Story' : 'Stories'}',
                ),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: theme.coverAuthor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Book-style PDF page footer: italic book title on the left, page number
  /// on the right. Hidden on the cover.
  static pw.Widget _buildPdfFooter(
    String bookTitle,
    int pageNumber,
    _PdfExportTheme theme,
    double contentWidth,
    String Function(String) pdfTxt,
  ) {
    return pw.Container(
      width: contentWidth,
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              pdfTxt(bookTitle),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 9,
                color: theme.muted,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
          pw.Text(
            '— $pageNumber —',
            style: pw.TextStyle(
              fontSize: 9,
              color: theme.muted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// PDF Table of Contents (only added when the book has 2+ stories).
  static pw.Widget _buildPdfTocPage(
    Ebook ebook,
    List<StoryBookItem> stories,
    _PdfExportTheme theme,
    double contentWidth,
    String Function(String) pdfTxt,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: theme.cardBg,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: theme.cardBorder, width: 1.2),
      ),
      padding: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt('C O N T E N T S'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                letterSpacing: 4,
                color: theme.muted,
                height: 1.4,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: contentWidth,
            child: pw.Text(
              pdfTxt('Table of Contents'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: theme.storyTitle,
                height: 1.2,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: theme.cardBorder, thickness: 1.6),
          pw.SizedBox(height: 18),
          for (var i = 0; i < stories.length; i++) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 30,
                  height: 30,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: theme.storyTitle,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    '${i + 1}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Text(
                    pdfTxt(stories[i].title),
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: theme.body,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (i < stories.length - 1) ...[
              pw.SizedBox(height: 8),
              pw.Divider(color: theme.cardBorder, thickness: 0.7),
              pw.SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _buildPdfChapterWidgets(
    StoryBookItem story,
    int chapterNumber,
    _PdfExportTheme theme,
    Map<String, pw.ImageProvider> cache,
    double contentWidth,
    PdfPageFormat format,
    String Function(String) pdfTxt,
  ) {
    final maxChapterCoverH = _EbookPdfLayout.maxChapterCoverHeightPt(format);
    final maxInlineH = _EbookPdfLayout.maxInlineImageHeightPt(format);

    final out = <pw.Widget>[
      // "C H A P T E R   N" tracked label.
      pw.Container(
        width: contentWidth,
        child: pw.Text(
          pdfTxt('C H A P T E R   $chapterNumber'),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            letterSpacing: 3,
            color: theme.muted,
            height: 1.4,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      // Story title.
      pw.Container(
        width: contentWidth,
        child: pw.Text(
          pdfTxt(story.title),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: theme.storyTitle,
            height: 1.22,
          ),
        ),
      ),
      pw.SizedBox(height: 6),
      // Author italic.
      pw.Container(
        width: contentWidth,
        child: pw.Text(
          pdfTxt('by ${story.authorName}'),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 12,
            fontStyle: pw.FontStyle.italic,
            color: theme.muted,
            height: 1.35,
          ),
        ),
      ),
      pw.SizedBox(height: 12),
    ];

    // Option B layout (matches the in-app reader):
    // Chapter label → Title → "by Author" → Cover image → ✦ divider → Body.
    final coverUrl = story.coverUrl?.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final prov = cache[coverUrl];
      if (prov != null) {
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
        out.add(pw.SizedBox(height: 12));
      }
    }

    // Decorative rule with central sparkle — placed after the cover so it
    // introduces the body text like a magazine chapter opener.
    out.add(
      pw.Row(children: [
        pw.Expanded(
          child: pw.Divider(color: theme.cardBorder, thickness: 1.4),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          '★',
          style: pw.TextStyle(color: theme.muted, fontSize: 11),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Divider(color: theme.cardBorder, thickness: 1.4),
        ),
      ]),
    );
    out.add(pw.SizedBox(height: 16));

    final blocks = ebookStoryBlocks(story);
    var anyBody = false;
    var dropCapApplied = false;

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
        continue;
      }

      final raw = (block['text'] as String?) ?? '';
      if (raw.trim().isEmpty) continue;
      anyBody = true;
      for (final para in raw.split(RegExp(r'\n\s*\n'))) {
        final p = para.trim();
        if (p.isEmpty) continue;

        if (_isSceneBreakLine(p)) {
          out.add(pw.SizedBox(height: 8));
          out.add(
            pw.Container(
              width: contentWidth,
              child: pw.Text(
                '★  ★  ★',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  color: theme.muted,
                  height: 1.4,
                ),
              ),
            ),
          );
          out.add(pw.SizedBox(height: 8));
          continue;
        }

        if (!dropCapApplied) {
          dropCapApplied = true;
          // Drop cap: first letter large, rest in normal body.
          final firstChar = pdfTxt(p.substring(0, 1));
          final rest = p.length > 1 ? pdfTxt(p.substring(1)) : '';
          out.add(pw.SizedBox(height: 10));
          out.add(
            pw.Container(
              width: contentWidth,
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: firstChar,
                      style: pw.TextStyle(
                        fontSize: 40,
                        fontWeight: pw.FontWeight.bold,
                        color: theme.storyTitle,
                        height: 0.9,
                      ),
                    ),
                    pw.TextSpan(
                      text: rest,
                      style: pw.TextStyle(
                        fontSize: 12.5,
                        height: 1.65,
                        letterSpacing: 0.15,
                        color: theme.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          continue;
        }

        for (final chunk in _splitTextForMultiPage(p)) {
          out.add(pw.SizedBox(height: 10));
          out.add(
            pw.Container(
              width: contentWidth,
              child: pw.Text(
                pdfTxt(chunk),
                textAlign: pw.TextAlign.justify,
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
    } else {
      // End-of-chapter ornament.
      out.add(pw.SizedBox(height: 22));
      out.add(
        pw.Container(
          width: contentWidth,
          child: pw.Text(
            '— ★ —',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 16,
              color: theme.muted,
              letterSpacing: 3,
            ),
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
  final List<StoryBookItem>? tocStories;
  final int chapterIndex; // 1-based; 0 = not a chapter.

  const EbookPageData._({
    this.ebook,
    this.story,
    this.tocStories,
    this.chapterIndex = 0,
  });

  factory EbookPageData.cover(Ebook ebook) => EbookPageData._(ebook: ebook);

  factory EbookPageData.toc(List<StoryBookItem> stories) =>
      EbookPageData._(tocStories: stories);

  factory EbookPageData.chapter(StoryBookItem story, int index) =>
      EbookPageData._(story: story, chapterIndex: index);

  bool get isCover => ebook != null && tocStories == null && story == null;
  bool get isToc => tocStories != null;
  bool get isChapter => story != null;
}

/// Cover → TOC (when 2+ stories) → one horizontal chapter page per story.
List<EbookPageData> buildEbookPages(Ebook ebook, List<StoryBookItem> stories) {
  return [
    EbookPageData.cover(ebook),
    if (stories.length >= 2) EbookPageData.toc(stories),
    for (var i = 0; i < stories.length; i++)
      EbookPageData.chapter(stories[i], i + 1),
  ];
}

/// Same ordered blocks as the write screen / Firestore `content` field.
List<Map<String, dynamic>> ebookStoryBlocks(StoryBookItem story) {
  final c = story.content;
  if (c != null && c.isNotEmpty) return c;
  return [StoryContentCodec.textBlock(story.body)];
}
