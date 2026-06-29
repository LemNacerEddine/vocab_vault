import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import 'add_word_screen.dart';
import 'word_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Word> _words = [];
  List<Word> _filteredWords = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    final words = await DatabaseHelper.instance.getAllWords();
    setState(() {
      _words = words;
      _filteredWords = words;
      _isLoading = false;
    });
  }

  void _filterWords(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredWords = _words;
      } else {
        _filteredWords = _words
            .where((w) =>
                w.word.toLowerCase().contains(query.toLowerCase()) ||
                w.translation.contains(query))
            .toList();
      }
    });
  }

  Future<void> _deleteWord(Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الكلمة'),
        content: Text('هل تريد حذف كلمة "${word.word}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteWord(word.id!);
      _loadWords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف "${word.word}"'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _openWordDetail(Word word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordDetailScreen(word: word),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن كلمة...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filterWords,
              )
            : const Text(
                'VocabVault',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        centerTitle: !_isSearching,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isSearching && _words.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredWords = _words;
                });
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _words.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // شريط الإحصائيات
                      _buildStatsBar(),
                      // قائمة الكلمات
                      Expanded(child: _buildWordList()),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddWordScreen()),
          );
          if (result == true) {
            _loadWords();
          }
        },
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('كلمة جديدة'),
      ),
    );
  }

  // شريط الإحصائيات
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.library_books,
            label: 'إجمالي الكلمات',
            value: '${_words.length}',
            color: Colors.deepPurple,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade300,
          ),
          _buildStatItem(
            icon: Icons.today,
            label: 'اليوم',
            value: '${_getTodayCount()}',
            color: Colors.green,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade300,
          ),
          _buildStatItem(
            icon: Icons.calendar_month,
            label: 'هذا الأسبوع',
            value: '${_getWeekCount()}',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  int _getTodayCount() {
    final today = DateTime.now();
    return _words
        .where((w) =>
            w.createdAt.year == today.year &&
            w.createdAt.month == today.month &&
            w.createdAt.day == today.day)
        .length;
  }

  int _getWeekCount() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _words.where((w) => w.createdAt.isAfter(weekAgo)).length;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories,
              size: 64,
              color: Colors.deepPurple.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ابدأ رحلتك مع الكلمات!',
            style: TextStyle(
              fontSize: 22,
              color: Colors.deepPurple.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على "كلمة جديدة" لإضافة أول كلمة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _filteredWords.length,
      itemBuilder: (context, index) {
        final word = _filteredWords[index];
        return Dismissible(
          key: Key(word.id.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('حذف الكلمة'),
                content: Text('هل تريد حذف كلمة "${word.word}"؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            await DatabaseHelper.instance.deleteWord(word.id!);
            _loadWords();
          },
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _openWordDetail(word),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // صورة أو حرف
                    _buildWordAvatar(word),
                    const SizedBox(width: 12),
                    // معلومات الكلمة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                word.word,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (word.phonetic != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  word.phonetic!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            word.translation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // شارات (tags)
                          Row(
                            children: [
                              if (word.partOfSpeech != null)
                                _buildTag(
                                    word.partOfSpeech!, Colors.deepPurple),
                              if (word.synonymsList.isNotEmpty)
                                _buildTag(
                                    '${word.synonymsList.length} مرادف',
                                    Colors.teal),
                              if (word.antonymsList.isNotEmpty)
                                _buildTag(
                                    '${word.antonymsList.length} ضد',
                                    Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // سهم التفاصيل
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordAvatar(Word word) {
    if (word.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: word.imageUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildLetterAvatar(word),
          errorWidget: (context, url, error) => _buildLetterAvatar(word),
        ),
      );
    }
    return _buildLetterAvatar(word);
  }

  Widget _buildLetterAvatar(Word word) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          word.word[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
