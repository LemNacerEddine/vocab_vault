import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import 'add_word_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Word> _words = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  // تحميل الكلمات من قاعدة البيانات
  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    final words = await DatabaseHelper.instance.getAllWords();
    setState(() {
      _words = words;
      _isLoading = false;
    });
  }

  // حذف كلمة مع تأكيد
  Future<void> _deleteWord(Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
          SnackBar(content: Text('تم حذف "${word.word}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VocabVault'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // عرض عدد الكلمات
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${_words.length} كلمة',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmptyState()
              : _buildWordList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // الانتقال إلى شاشة إضافة كلمة جديدة
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddWordScreen()),
          );
          // إعادة تحميل الكلمات إذا تمت الإضافة بنجاح
          if (result == true) {
            _loadWords();
          }
        },
        tooltip: 'إضافة كلمة جديدة',
        child: const Icon(Icons.add),
      ),
    );
  }

  // واجهة عندما لا توجد كلمات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد كلمات بعد',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة كلمة جديدة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // قائمة الكلمات
  Widget _buildWordList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final word = _words[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                word.word[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              word.word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              word.translation,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteWord(word),
            ),
          ),
        );
      },
    );
  }
}
