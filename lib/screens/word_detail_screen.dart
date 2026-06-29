import 'package:flutter/material.dart';
import '../models/word.dart';

class WordDetailScreen extends StatelessWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(word.word),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الكلمة الرئيسية
            _buildMainCard(context),
            const SizedBox(height: 16),

            // بطاقة التعريف
            if (word.definition != null) _buildDefinitionCard(),
            const SizedBox(height: 16),

            // بطاقة المثال
            if (word.example != null) _buildExampleCard(),
            const SizedBox(height: 16),

            // تاريخ الإضافة
            _buildDateCard(),
          ],
        ),
      ),
    );
  }

  // بطاقة الكلمة الرئيسية
  Widget _buildMainCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // الكلمة بالإنجليزية
            Text(
              word.word,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),

            // النطق الصوتي
            if (word.phonetic != null)
              Text(
                word.phonetic!,
                style: TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),

            // نوع الكلمة
            if (word.partOfSpeech != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  word.partOfSpeech!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),

            const Divider(height: 32),

            // الترجمة بالعربية
            const Text(
              'الترجمة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              word.translation,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة التعريف
  Widget _buildDefinitionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: Colors.deepPurple.shade300),
                const SizedBox(width: 8),
                const Text(
                  'Definition',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              word.definition!,
              style: const TextStyle(fontSize: 15, height: 1.5),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة المثال
  Widget _buildExampleCard() {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_quote, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Example',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              '"${word.example!}"',
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة التاريخ
  Widget _buildDateCard() {
    return Card(
      elevation: 1,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'تمت الإضافة: ${_formatDate(word.createdAt)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
