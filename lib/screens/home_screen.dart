import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../models/word.dart';
import '../services/notification_service.dart';
import '../services/review_session_builder.dart';
import '../utils/pos_category.dart';
import 'add_word_screen.dart';
import 'word_detail_screen.dart';
import 'quiz_screen.dart';

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
  int _dueCount = 0;
  String _searchQuery = '';
  PosCategory? _selectedCategory; // null = الكل
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
    final dueCount = await DatabaseHelper.instance.getDueCount();
    setState(() {
      _words = words;
      _dueCount = dueCount;
      _isLoading = false;
    });
    _recomputeFiltered();
    // تحديث نص إشعار التذكير اليومي بالعدد الجديد للكلمات المستحقّة
    // (بعد كل جلسة/إضافة/حذف). غير حاجب للواجهة.
    NotificationService.rescheduleWithFreshCount();
  }

  // إعادة حساب القائمة المعروضة وفق المجموعة المختارة ونص البحث معاً.
  void _recomputeFiltered() {
    var list = _words;
    if (_selectedCategory != null) {
      list = PosCategoryUtil.filter(list, _selectedCategory!);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((w) =>
              w.word.toLowerCase().contains(q) ||
              w.translation.contains(_searchQuery))
          .toList();
    }
    setState(() => _filteredWords = list);
  }

  void _selectCategory(PosCategory? category) {
    _selectedCategory = category;
    _recomputeFiltered();
  }

  // بدء جلسة اختبار. [subset] لاختبار مجموعة محدّدة (تصنيف أو كلمات صعبة)؛
  // وإلا تُبنى الجلسة من الكلمات المستحقّة للمراجعة الآن.
  Future<void> _startQuiz({List<Word>? subset}) async {
    final source = subset ?? await DatabaseHelper.instance.getDueWords();
    if (source.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد كلمات كافية للاختبار الآن. أضف المزيد!'),
        ),
      );
      return;
    }

    final progressMap = await DatabaseHelper.instance.getAllProgressMap();
    final questions = ReviewSessionBuilder.buildSession(
      words: source,
      progress: progressMap,
    );

    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات كافية لبناء أسئلة الآن. أضف تفاصيل أكثر للكلمات (صور/أمثلة/مرادفات).'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuizScreen(questions: questions)),
    );
    _loadWords();
  }

  // بدء جلسة تركّز على "الكلمات الصعبة" (أكثر الكلمات خطأً).
  Future<void> _startWeakWordsQuiz() async {
    final weak = await DatabaseHelper.instance.getWeakWords();
    if (!mounted) return;
    if (weak.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد كلمات صعبة مسجَّلة بعد — استمر في المراجعة!')),
      );
      return;
    }
    await _startQuiz(subset: weak);
  }

  void _filterWords(String query) {
    _searchQuery = query;
    _recomputeFiltered();
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
                'Mofradati',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        centerTitle: !_isSearching,
        backgroundColor: AppColors.brand,
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
                  _searchQuery = '';
                });
                _recomputeFiltered();
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
              AppColors.brand.shade50,
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
                      // زر بدء المراجعة
                      _buildReviewBanner(),
                      // زر التركيز على الكلمات الصعبة
                      _buildWeakWordsButton(),
                      // تبويبات التصنيف (أسماء/أفعال/صفات)
                      _buildCategoryChips(),
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
        backgroundColor: AppColors.brand,
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
            color: AppColors.brand.withOpacity(0.1),
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
            color: AppColors.brand,
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

  // زر صغير لبدء جلسة مركَّزة على الكلمات التي يخطئ فيها المستخدم كثيراً
  Widget _buildWeakWordsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _startWeakWordsQuiz,
          icon: Icon(Icons.trending_down, size: 18, color: Colors.red.shade600),
          label: Text(
            'الكلمات الصعبة',
            style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // تبويبات تصنيف الكلمات حسب النوع (أسماء/أفعال/صفات/أخرى)
  Widget _buildCategoryChips() {
    // عدّ الكلمات لكل مجموعة.
    final counts = <PosCategory, int>{};
    for (final w in _words) {
      final c = PosCategoryUtil.ofWord(w);
      counts[c] = (counts[c] ?? 0) + 1;
    }
    // المجموعات التي بها كلمات فقط.
    final present = PosCategory.values.where((c) => (counts[c] ?? 0) > 0);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _categoryChip(label: 'الكل (${_words.length})', category: null),
          for (final c in present)
            _categoryChip(
              label: '${c.labelAr} (${counts[c]})',
              category: c,
            ),
          if (_selectedCategory != null && _filteredWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ActionChip(
                avatar: const Icon(Icons.quiz, size: 18,
                    color: AppColors.brand),
                label: const Text('اختبر المجموعة'),
                onPressed: () => _startQuiz(subset: _filteredWords),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip({required String label, required PosCategory? category}) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.brand,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.brand.shade700,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.brand.shade100),
        onSelected: (_) => _selectCategory(category),
      ),
    );
  }

  // بطاقة بدء جلسة المراجعة
  Widget _buildReviewBanner() {
    final hasDue = _dueCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: hasDue ? AppColors.brand : AppColors.brand.shade200,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _startQuiz,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.psychology_alt, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ابدأ المراجعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        hasDue
                            ? '$_dueCount كلمة مستحقّة للمراجعة اليوم'
                            : 'راجع كلماتك بأسئلة متنوّعة',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 30),
              ],
            ),
          ),
        ),
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
              color: AppColors.brand.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories,
              size: 64,
              color: AppColors.brand.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ابدأ رحلتك مع الكلمات!',
            style: TextStyle(
              fontSize: 22,
              color: AppColors.brand.shade700,
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
                                    word.partOfSpeech!, AppColors.brand),
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
          colors: [AppColors.brand.shade400, AppColors.brand.shade600],
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
