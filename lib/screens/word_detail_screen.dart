import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/word.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // تشغيل النطق الصوتي
  Future<void> _playAudio() async {
    if (widget.word.audioUrl == null || widget.word.audioUrl!.isEmpty) return;

    try {
      setState(() => _isPlaying = true);
      await _audioPlayer.play(UrlSource(widget.word.audioUrl!));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن تشغيل الصوت. تحقق من اتصال الإنترنت.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word.word),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصورة التوضيحية (إن وجدت)
            if (widget.word.imageUrl != null) _buildImageCard(),

            // بطاقة الكلمة الرئيسية
            _buildMainCard(context),
            const SizedBox(height: 16),

            // بطاقة التعريف
            if (widget.word.definition != null) _buildDefinitionCard(),
            if (widget.word.definition != null) const SizedBox(height: 16),

            // بطاقة المثال
            if (widget.word.example != null) _buildExampleCard(),
            if (widget.word.example != null) const SizedBox(height: 16),

            // تاريخ الإضافة
            _buildDateCard(),
          ],
        ),
      ),
    );
  }

  // بطاقة الصورة التوضيحية
  Widget _buildImageCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: widget.word.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 50),
              ),
            ),
          ),
          if (widget.word.imageDescription != null &&
              widget.word.imageDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.word.imageDescription!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              ),
            ),
        ],
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
              widget.word.word,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),

            // النطق الصوتي مع زر التشغيل
            if (widget.word.phonetic != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.word.phonetic!,
                    style: TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (widget.word.audioUrl != null &&
                      widget.word.audioUrl!.isNotEmpty)
                    IconButton(
                      onPressed: _isPlaying ? null : _playAudio,
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                    ),
                ],
              ),

            // نوع الكلمة
            if (widget.word.partOfSpeech != null)
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
                  widget.word.partOfSpeech!,
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
              widget.word.translation,
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
              widget.word.definition!,
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
              '"${widget.word.example!}"',
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
              'تمت الإضافة: ${_formatDate(widget.word.createdAt)}',
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
