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
      body: CustomScrollView(
        slivers: [
          // AppBar مع صورة خلفية
          _buildSliverAppBar(),
          // المحتوى
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة الكلمة الرئيسية
                  _buildMainWordCard(),
                  const SizedBox(height: 16),

                  // بطاقة التعريفات
                  if (widget.word.definition != null) _buildDefinitionsCard(),
                  if (widget.word.definition != null) const SizedBox(height: 16),

                  // بطاقة الأمثلة
                  if (widget.word.allExamples != null &&
                      widget.word.allExamples!.isNotEmpty)
                    _buildExamplesCard(),
                  if (widget.word.allExamples != null &&
                      widget.word.allExamples!.isNotEmpty)
                    const SizedBox(height: 16),

                  // بطاقة المرادفات والأضداد
                  if ((widget.word.synonyms != null &&
                          widget.word.synonyms!.isNotEmpty) ||
                      (widget.word.antonyms != null &&
                          widget.word.antonyms!.isNotEmpty))
                    _buildSynonymsAntonymsCard(),

                  const SizedBox(height: 16),

                  // تاريخ الإضافة
                  _buildDateCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // AppBar مع صورة
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: widget.word.imageUrl != null ? 220 : 120,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.word.word,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        background: widget.word.imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.word.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.deepPurple.shade200,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.deepPurple.shade200,
                      child: const Icon(Icons.broken_image,
                          size: 50, color: Colors.white54),
                    ),
                  ),
                  // تدرج لوني لقراءة النص
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade700,
                      Colors.deepPurple.shade400,
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // بطاقة الكلمة الرئيسية
  Widget _buildMainWordCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // النطق الصوتي مع زر التشغيل
            if (widget.word.phonetic != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.word.phonetic!,
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    if (widget.word.audioUrl != null &&
                        widget.word.audioUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isPlaying ? null : _playAudio,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // أنواع الكلمة
            if (widget.word.allPartsOfSpeech != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: widget.word.allPartsOfSpeech!
                    .split(',')
                    .where((s) => s.trim().isNotEmpty)
                    .map((pos) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPartOfSpeechColor(pos.trim()).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _getPartOfSpeechColor(pos.trim()).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      pos.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _getPartOfSpeechColor(pos.trim()),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const Divider(height: 32),

            // الترجمة بالعربية
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.translate,
                          size: 18, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'الترجمة',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.word.translation,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة التعريفات
  Widget _buildDefinitionsCard() {
    final definitions = widget.word.definitionsList;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.menu_book, color: Colors.blue.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'التعريفات (Definitions)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (definitions.isNotEmpty)
              ...definitions.take(5).toList().asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                );
              })
            else if (widget.word.definition != null)
              Text(
                widget.word.definition!,
                style: const TextStyle(fontSize: 14, height: 1.5),
                textDirection: TextDirection.ltr,
              ),
          ],
        ),
      ),
    );
  }

  // بطاقة الأمثلة
  Widget _buildExamplesCard() {
    final examples = widget.word.examplesList;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.format_quote,
                      color: Colors.amber.shade700, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'أمثلة (Examples)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...examples.take(5).map((example) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$example"',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // بطاقة المرادفات والأضداد
  Widget _buildSynonymsAntonymsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المرادفات
            if (widget.word.synonymsList.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.compare_arrows,
                        color: Colors.teal.shade600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'المرادفات (Synonyms)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.word.synonymsList.take(10).map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      s.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (widget.word.synonymsList.isNotEmpty &&
                widget.word.antonymsList.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),

            // الأضداد
            if (widget.word.antonymsList.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.swap_horiz,
                        color: Colors.red.shade600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الأضداد (Antonyms)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.word.antonymsList.take(10).map((a) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      a.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // بطاقة التاريخ
  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
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
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Color _getPartOfSpeechColor(String partOfSpeech) {
    switch (partOfSpeech.toLowerCase().trim()) {
      case 'noun':
        return Colors.blue.shade700;
      case 'verb':
        return Colors.green.shade700;
      case 'adjective':
        return Colors.orange.shade700;
      case 'adverb':
        return Colors.purple.shade700;
      case 'interjection':
        return Colors.pink.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
