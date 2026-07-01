import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/word.dart';
import '../database/database_helper.dart';
import '../services/claude_service.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isGeneratingQuiz = false;
  late bool _hasQuizContent =
      widget.word.quizContent != null && widget.word.quizContent!.isNotEmpty;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // توليد حزمة أسئلة ذكية بالـ AI لكلمة موجودة (عند الطلب).
  Future<void> _generateQuiz() async {
    if (widget.word.id == null) return;
    setState(() => _isGeneratingQuiz = true);
    final pack = await ClaudeService.generateQuizPack(widget.word);
    if (pack != null) {
      await DatabaseHelper.instance.updateWord(
        widget.word.copyWith(quizContent: pack.encode()),
      );
    }
    if (!mounted) return;
    setState(() {
      _isGeneratingQuiz = false;
      _hasQuizContent = pack != null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pack != null
              ? 'تم توليد أسئلة ذكية لهذه الكلمة ✓'
              : 'تعذّر توليد الأسئلة. تحقق من المفتاح والاتصال.',
        ),
        backgroundColor: pack != null ? Colors.green : Colors.red.shade400,
      ),
    );
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
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة الكلمة الرئيسية مع الصوت
                  _buildMainWordCard(),
                  const SizedBox(height: 16),

                  // بطاقة معلومات الجذر (تظهر فقط إذا كانت الكلمة جمعاً أو متصرفة)
                  if (widget.word.rootWord != null) ...[  
                    _buildRootWordCard(),
                    const SizedBox(height: 16),
                  ],

                  // بطاقة التعريفات
                  if (widget.word.definition != null) _buildDefinitionsCard(),
                  if (widget.word.definition != null) const SizedBox(height: 16),

                  // بطاقة الأمثلة (تدمج أمثلة الجذر + أمثلة الصيغة المدخلة)
                  if (widget.word.allExamplesMerged.isNotEmpty)
                    _buildExamplesCard(),
                  if (widget.word.allExamplesMerged.isNotEmpty)
                    const SizedBox(height: 16),

                  // بطاقة المرادفات والأضداد
                  if ((widget.word.synonyms != null &&
                          widget.word.synonyms!.isNotEmpty) ||
                      (widget.word.antonyms != null &&
                          widget.word.antonyms!.isNotEmpty))
                    _buildSynonymsAntonymsCard(),
                  if ((widget.word.synonyms != null &&
                          widget.word.synonyms!.isNotEmpty) ||
                      (widget.word.antonyms != null &&
                          widget.word.antonyms!.isNotEmpty))
                    const SizedBox(height: 16),

                  // بطاقة الصور التوضيحية
                  if (widget.word.imageUrlsList.isNotEmpty)
                    _buildImagesGalleryCard(),
                  if (widget.word.imageUrlsList.isNotEmpty)
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

  // AppBar مع صورة خلفية
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: widget.word.imageUrl != null ? 220 : 120,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      actions: [
        if (ClaudeService.isEnabled && !_hasQuizContent)
          _isGeneratingQuiz
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'توليد أسئلة ذكية',
                  onPressed: _generateQuiz,
                ),
      ],
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

  // بطاقة الكلمة الرئيسية مع زر الصوت البارز
  Widget _buildMainWordCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // زر تشغيل الصوت البارز
            if (widget.word.audioUrl != null &&
                widget.word.audioUrl!.isNotEmpty) ...[
              GestureDetector(
                onTap: _isPlaying ? null : _playAudio,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isPlaying
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isPlaying ? 'جاري التشغيل...' : 'استمع للنطق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.word.phonetic != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          widget.word.phonetic!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (widget.word.phonetic != null) ...[
              // عرض النطق بدون صوت
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
                    Icon(Icons.record_voice_over,
                        size: 18, color: Colors.deepPurple.shade400),
                    const SizedBox(width: 8),
                    Text(
                      widget.word.phonetic!,
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // أنواع الكلمة
            if (widget.word.allPartsOfSpeech != null) ...[
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
                      color:
                          _getPartOfSpeechColor(pos.trim()).withOpacity(0.1),
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
              const SizedBox(height: 12),
            ],

            const Divider(height: 24),

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
                  child: Icon(Icons.menu_book,
                      color: Colors.blue.shade600, size: 20),
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

  // بطاقة معلومات الجذر
  Widget _buildRootWordCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.orange.shade50,
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.account_tree_outlined,
                      color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'معلومات الصيغة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.orange.shade900, height: 1.6),
                children: [
                  TextSpan(
                    text: widget.word.word,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(text: ' هي '),
                  TextSpan(
                    text: widget.word.formTypeLabel ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' لـ '),
                  TextSpan(
                    text: widget.word.rootWord!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                    ),
                  ),
                  const TextSpan(text: '. تم جلب معلومات الكلمة الأصلية مع دمج أمثلتها لتسهيل الحفظ.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة الأمثلة
  Widget _buildExamplesCard() {
    final rootExamples = widget.word.examplesList;
    final inputFormExamples = widget.word.inputFormExamplesList;
    final allExamples = widget.word.allExamplesMerged;
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
                Expanded(
                  child: Text(
                    'أمثلة (Examples)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
                // عدد الأمثلة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${allExamples.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...allExamples.take(6).map((example) {
              // هل هذا المثال من الصيغة المدخلة (الجمع مثلاً)؟
              final isInputFormExample = inputFormExamples.contains(example);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInputFormExample ? Colors.blue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isInputFormExample ? Colors.blue.shade200 : Colors.amber.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isInputFormExample) ...[  
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'مثال بالصيغة المدخلة (${widget.word.word})',
                            style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      example,
                      style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
                      textDirection: TextDirection.ltr,
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

  // بطاقة معرض الصور التوضيحية
  Widget _buildImagesGalleryCard() {
    final images = widget.word.imageUrlsList;
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
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library,
                      color: Colors.purple.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'صور توضيحية (Visual Context)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'هذه الصور تساعدك على ربط الكلمة بصريًا',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const Divider(height: 20),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _showFullImage(context, images[index]),
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                            // أيقونة التكبير
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عرض الصورة بحجم كامل
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
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
