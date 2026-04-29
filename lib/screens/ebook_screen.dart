import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show networkImage;

import 'theme.dart';
import '../utils/pdf_file_exporter.dart';

const _kEbookPageBackground = Color(0xFFF5F5F5);
const _kEbookCardBackground = Color(0xFFFFF4FB);
const _kEbookCardBorder = Color(0xFFEADAE8);
const _kEbookIconBackground = Color(0xFFF1E3F7);
const _kEbookTitleColor = Color(0xFF241627);
const _kEbookMutedText = Color(0xFF5F5262);

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
      return Scaffold(
        appBar: _buildAppBar('E-Book Creator'),
        body: const Center(child: Text('Please log in to create an eBook.')),
      );
    }

    return Scaffold(
      backgroundColor: _kEbookPageBackground,
      appBar: _buildAppBar('My E-Books'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('ebooks')
            .where('userId', isEqualTo: _user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load eBooks: ${snapshot.error}'));
          }

          final ebooks = (snapshot.data?.docs ?? [])
              .map(Ebook.fromDocument)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ebooks.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CreateEbookCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EbookCreatorScreen(),
                      ),
                    );
                  },
                );
              }

              final ebook = ebooks[index - 1];
              return _EbookLibraryCard(
                ebook: ebook,
                isExporting: _exportingEbookId == ebook.ebookId,
                onTap: () => _openEbook(ebook),
                onDownload: () => _exportEbook(ebook, share: false),
                onShare: () => _exportEbook(ebook, share: true),
                onDelete: () => _confirmDeleteEbook(ebook),
              );
            },
          );
        },
      ),
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
    final docs = await Future.wait(
      ebook.storyIds
          .map((storyId) => _db.collection('stories').doc(storyId).get()),
    );

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
  const EbookCreatorScreen({super.key});

  @override
  State<EbookCreatorScreen> createState() => _EbookCreatorScreenState();
}

class _EbookCreatorScreenState extends State<EbookCreatorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  List<StoryBookItem> _selectedStories = [];
  bool _isCreating = false;

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
      final ebookRef = _db.collection('ebooks').doc();
      final coverImage = _selectedStories
          .map((story) => story.coverUrl)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);

      final ebook = Ebook(
        ebookId: ebookRef.id,
        userId: user.uid,
        title: title,
        authorName: user.displayName ?? _selectedStories.first.authorName,
        coverImage: coverImage,
        storyIds: _selectedStories.map((story) => story.id).toList(),
        createdAt: DateTime.now(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create eBook: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: _buildAppBar('Create E-Book'),
        body: const Center(child: Text('Please log in to create an eBook.')),
      );
    }

    return Scaffold(
      backgroundColor: _kEbookPageBackground,
      appBar: _buildAppBar('Create E-Book'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EbookHeader(
            controller: _titleController,
            selectedCount: _selectedStories.length,
            onChooseStories: _chooseStories,
            onCreate: _isCreating ? null : _createEbook,
            isCreating: _isCreating,
          ),
          if (_selectedStories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Selected stories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _kEbookTitleColor,
                  ),
            ),
            const SizedBox(height: 10),
            ..._selectedStories.map(
              (story) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SelectedStoryPreview(story: story),
              ),
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
              .where((story) => story.body.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (stories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Write a story first, then come back to turn it into a book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, height: 1.4),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final story = stories[index];
              final isSelected = _selectedStoryIds.contains(story.id);

              return _StorySelectionCard(
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
  static const int _charactersPerPage = 520;

  late final PageController _pageController;
  late final List<EbookPageData> _pages;
  int _currentPage = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = _buildPages(widget.ebook, widget.stories);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<EbookPageData> _buildPages(Ebook ebook, List<StoryBookItem> stories) {
    final pages = <EbookPageData>[EbookPageData.cover(ebook)];

    for (final story in stories) {
      final chunks = _paginateText(story.body, _charactersPerPage);
      for (var index = 0; index < chunks.length; index++) {
        pages.add(
          EbookPageData.story(
            story: story,
            text: chunks[index],
            partNumber: index + 1,
            totalParts: chunks.length,
          ),
        );
      }
    }

    return pages;
  }

  List<String> _paginateText(String text, int maxCharacters) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const [];

    final pages = <String>[];
    var start = 0;

    while (start < normalized.length) {
      var end = (start + maxCharacters).clamp(0, normalized.length).toInt();
      if (end < normalized.length) {
        final lastSpace = normalized.lastIndexOf(' ', end);
        if (lastSpace > start + 120) {
          end = lastSpace;
        }
      }

      pages.add(normalized.substring(start, end).trim());
      start = end;
      while (start < normalized.length && normalized[start] == ' ') {
        start++;
      }
    }

    return pages;
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

  Future<Uint8List> _buildPdf() async {
    final document = pw.Document();
    final imageCache = <String, pw.ImageProvider>{};

    for (final page in _pages) {
      final imageUrl = page.imageUrl;
      pw.ImageProvider? image;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        image = imageCache[imageUrl] ??= await networkImage(imageUrl);
      }

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            if (page.isCover) {
              return _buildPdfCover(page.ebook!, image);
            }

            return _buildPdfStoryPage(page, image);
          },
        ),
      );
    }

    return document.save();
  }

  pw.Widget _buildPdfCover(Ebook ebook, pw.ImageProvider? image) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF4FB'),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromHex('#8E44AD'), width: 2),
      ),
      padding: const pw.EdgeInsets.all(34),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (image != null)
            pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.Image(image, height: 280, fit: pw.BoxFit.cover),
            ),
          pw.SizedBox(height: 34),
          pw.Text(
            ebook.title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 34,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#5C2D91'),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'by ${ebook.authorName}',
            style:
                pw.TextStyle(fontSize: 18, color: PdfColor.fromHex('#555555')),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStoryPage(EbookPageData page, pw.ImageProvider? image) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF4FB'),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromHex('#EADAE8'), width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(26),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            page.story!.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#5C2D91'),
            ),
          ),
          if (page.totalParts > 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Page ${page.partNumber} of ${page.totalParts}',
                style: pw.TextStyle(
                    fontSize: 11, color: PdfColor.fromHex('#777777')),
              ),
            ),
          if (image != null && page.partNumber == 1) ...[
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(image, height: 210, fit: pw.BoxFit.cover),
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Expanded(
            child: pw.Text(
              page.text,
              style: const pw.TextStyle(fontSize: 18, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  String _safeFileName(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'pixiepen_ebook' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kEbookPageBackground,
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
                          ? _BookCoverPage(ebook: page.ebook!)
                          : _StoryBookPage(page: page),
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
                        backgroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentPage + 1}/${_pages.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kAppPrimary,
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
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _EbookLibraryCard({
    required this.ebook,
    required this.isExporting,
    required this.onTap,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
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
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                  ),
                  const Icon(Icons.menu_book, color: kAppPrimary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedStoryPreview extends StatelessWidget {
  final StoryBookItem story;

  const _SelectedStoryPreview({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kEbookCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kEbookCardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          _StoryThumbnail(imageUrl: story.coverUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _kEbookTitleColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  story.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kEbookMutedText, height: 1.3),
                ),
              ],
            ),
          ),
        ],
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

  const _EbookHeader({
    required this.controller,
    required this.selectedCount,
    required this.onChooseStories,
    required this.onCreate,
    required this.isCreating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kEbookCardBackground,
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
                label: Text(isCreating ? 'Creating' : 'Preview'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorySelectionCard extends StatelessWidget {
  final StoryBookItem story;
  final bool isSelected;
  final VoidCallback onTap;

  const _StorySelectionCard({
    required this.story,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: _kEbookCardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kAppPrimary : _kEbookCardBorder,
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _StoryThumbnail(imageUrl: story.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kEbookTitleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      story.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        height: 1.3,
                        color: _kEbookMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? kAppPrimary : Colors.grey.shade500,
                size: 30,
              ),
            ],
          ),
        ),
      ),
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
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
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

  const _BookCoverPage({required this.ebook});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kEbookCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kAppPrimary, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ebook.coverImage != null && ebook.coverImage!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                ebook.coverImage!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 28),
          Text(
            ebook.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: _kEbookTitleColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'by ${ebook.authorName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _kEbookMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryBookPage extends StatelessWidget {
  final EbookPageData page;

  const _StoryBookPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final story = page.story!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kEbookCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kEbookCardBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: _kEbookTitleColor,
            ),
          ),
          if (page.totalParts > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Part ${page.partNumber} of ${page.totalParts}',
                style: const TextStyle(
                  color: _kEbookMutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (story.coverUrl != null &&
              story.coverUrl!.isNotEmpty &&
              page.partNumber == 1) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                story.coverUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                page.text,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.55,
                  color: Color(0xFF242124),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EbookPdfGenerator {
  static const int _charactersPerPage = 520;

  static Future<Uint8List> buildPdf(
    Ebook ebook,
    List<StoryBookItem> stories,
  ) async {
    final pages = _buildPages(ebook, stories);
    final document = pw.Document();
    final imageCache = <String, pw.ImageProvider>{};

    for (final page in pages) {
      final imageUrl = page.imageUrl;
      pw.ImageProvider? image;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          image = imageCache[imageUrl] ??= await networkImage(imageUrl);
        } catch (_) {
          image = null;
        }
      }

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            if (page.isCover) {
              return _buildPdfCover(page.ebook!, image);
            }

            return _buildPdfStoryPage(page, image);
          },
        ),
      );
    }

    return document.save();
  }

  static String safeFileName(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'pixiepen_ebook' : cleaned;
  }

  static List<EbookPageData> _buildPages(
    Ebook ebook,
    List<StoryBookItem> stories,
  ) {
    final pages = <EbookPageData>[EbookPageData.cover(ebook)];

    for (final story in stories) {
      final chunks = _paginateText(story.body, _charactersPerPage);
      for (var index = 0; index < chunks.length; index++) {
        pages.add(
          EbookPageData.story(
            story: story,
            text: chunks[index],
            partNumber: index + 1,
            totalParts: chunks.length,
          ),
        );
      }
    }

    return pages;
  }

  static List<String> _paginateText(String text, int maxCharacters) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const [];

    final pages = <String>[];
    var start = 0;

    while (start < normalized.length) {
      var end = (start + maxCharacters).clamp(0, normalized.length).toInt();
      if (end < normalized.length) {
        final lastSpace = normalized.lastIndexOf(' ', end);
        if (lastSpace > start + 120) {
          end = lastSpace;
        }
      }

      pages.add(normalized.substring(start, end).trim());
      start = end;
      while (start < normalized.length && normalized[start] == ' ') {
        start++;
      }
    }

    return pages;
  }

  static pw.Widget _buildPdfCover(Ebook ebook, pw.ImageProvider? image) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF4FB'),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromHex('#8E44AD'), width: 2),
      ),
      padding: const pw.EdgeInsets.all(34),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (image != null)
            pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.Image(image, height: 280, fit: pw.BoxFit.cover),
            ),
          pw.SizedBox(height: 34),
          pw.Text(
            ebook.title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 34,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#5C2D91'),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'by ${ebook.authorName}',
            style:
                pw.TextStyle(fontSize: 18, color: PdfColor.fromHex('#555555')),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfStoryPage(
    EbookPageData page,
    pw.ImageProvider? image,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF4FB'),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromHex('#EADAE8'), width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(26),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            page.story!.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#5C2D91'),
            ),
          ),
          if (page.totalParts > 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Page ${page.partNumber} of ${page.totalParts}',
                style: pw.TextStyle(
                    fontSize: 11, color: PdfColor.fromHex('#777777')),
              ),
            ),
          if (image != null && page.partNumber == 1) ...[
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(image, height: 210, fit: pw.BoxFit.cover),
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Expanded(
            child: pw.Text(
              page.text,
              style: const pw.TextStyle(fontSize: 18, height: 1.45),
            ),
          ),
        ],
      ),
    );
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

  const Ebook({
    required this.ebookId,
    required this.userId,
    required this.title,
    required this.authorName,
    required this.coverImage,
    required this.storyIds,
    required this.createdAt,
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
    );
  }
}

class StoryBookItem {
  final String id;
  final String title;
  final String body;
  final String authorName;
  final String? coverUrl;
  final DateTime createdAt;

  const StoryBookItem({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
    required this.coverUrl,
    required this.createdAt,
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
      authorName: (data['authorName'] as String?) ?? 'PixiePen Author',
      coverUrl: data['coverUrl'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class EbookPageData {
  final Ebook? ebook;
  final StoryBookItem? story;
  final String text;
  final int partNumber;
  final int totalParts;

  const EbookPageData._({
    this.ebook,
    this.story,
    required this.text,
    required this.partNumber,
    required this.totalParts,
  });

  factory EbookPageData.cover(Ebook ebook) {
    return EbookPageData._(
      ebook: ebook,
      text: '',
      partNumber: 1,
      totalParts: 1,
    );
  }

  factory EbookPageData.story({
    required StoryBookItem story,
    required String text,
    required int partNumber,
    required int totalParts,
  }) {
    return EbookPageData._(
      story: story,
      text: text,
      partNumber: partNumber,
      totalParts: totalParts,
    );
  }

  bool get isCover => ebook != null;

  String? get imageUrl => isCover ? ebook?.coverImage : story?.coverUrl;
}
