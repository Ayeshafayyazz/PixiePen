import 'package:flutter/material.dart';

class EbookScreen extends StatelessWidget {
  const EbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        title: const Text("E-Books", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: demoBooks.length,
        itemBuilder: (context, index) {
          final book = demoBooks[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EbookDetailScreen(
                    book: book,
                    chapters: demoChapters[book.id] ?? [],
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      height: 160,
                      width: double.infinity,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "by ${book.author}",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EbookDetailScreen extends StatelessWidget {
  final Ebook book;
  final List<String> chapters;

  const EbookDetailScreen({
    super.key,
    required this.book,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        title: Text(book.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                book.coverUrl,
                height: 200,
                width: 140,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              book.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              "by ${book.author}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                      backgroundColor: scheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    title: Text(chapters[index]),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Open chapter reading screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChapterReaderScreen(
                            bookTitle: book.title,
                            chapterTitle: chapters[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Chapter reader screen
class ChapterReaderScreen extends StatelessWidget {
  final String bookTitle;
  final String chapterTitle;

  const ChapterReaderScreen({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        title: Text(chapterTitle, style: const TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            _dummyChapterText(chapterTitle),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ),
    );
  }

  // Dummy text for chapters
  String _dummyChapterText(String chapter) {
    return "📖 $chapter\n\n" +
        List<String>.generate(
            5,
                (i) =>
            "This is some dummy content for $chapter. It contains exciting events and storytelling that make the reader engaged.")
            .join("\n\n");
  }
}

// Ebook model
class Ebook {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;

  Ebook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
  });
}

// Demo books
final demoBooks = [
  Ebook(
    id: "1",
    title: "The Secret Garden",
    author: "Frances Hodgson Burnett",
    coverUrl: "https://picsum.photos/id/237/400/600",
    description:
    "A magical story of friendship, discovery, and healing in a hidden garden.",
  ),
  Ebook(
    id: "2",
    title: "Alice in Wonderland",
    author: "Lewis Carroll",
    coverUrl: "https://picsum.photos/id/238/400/600",
    description:
    "Alice falls into a whimsical world filled with curious characters and wild adventures.",
  ),
  Ebook(
    id: "3",
    title: "The Little Prince",
    author: "Antoine de Saint-Exupéry",
    coverUrl: "https://picsum.photos/id/239/400/600",
    description:
    "A poetic tale about love, loss, and looking at life through the eyes of a child.",
  ),
];

// Demo chapters for each book
final Map<String, List<String>> demoChapters = {
  "1": ["The Magical Garden", "The Hidden Key"], // Secret Garden
  "2": ["Down the Rabbit Hole", "The Tea Party"], // Alice in Wonderland
  "3": ["The Planet of the Little Prince", "The Fox Story"], // The Little Prince
};
