import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../database/database_helper.dart';
import '../models/quiz_question.dart';
import '../models/word.dart';
import '../models/word_progress.dart';
import '../services/spaced_repetition_service.dart';

/// شاشة جلسة اختبار: تعرض الأسئلة تباعاً، تصحّح فورياً، وتحدّث جدولة SM-2.
class QuizScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizScreen({super.key, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _index = 0;
  QuizOption? _selected;
  bool _answered = false;
  int _correctCount = 0;
  final List<Word> _hardWords = [];
  DateTime _questionStart = DateTime.now();

  QuizQuestion get _current => widget.questions[_index];
  bool get _isFinished => _index >= widget.questions.length;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تشغيل الصوت')),
        );
      }
    }
  }

  Future<void> _onSelect(QuizOption option) async {
    if (_answered) return;
    final correct = option.isCorrect;
    final timeTaken = DateTime.now().difference(_questionStart);

    setState(() {
      _selected = option;
      _answered = true;
      if (correct) {
        _correctCount++;
      } else {
        _hardWords.add(_current.word);
      }
    });

    await _persistResult(_current.word, correct, timeTaken);
  }

  Future<void> _persistResult(
    Word word,
    bool correct,
    Duration timeTaken,
  ) async {
    final id = word.id;
    if (id == null) return;
    final db = DatabaseHelper.instance;
    final current = await db.getProgress(id) ?? WordProgress.initial(id);
    final updated = SpacedRepetitionService.applyAnswer(
      current,
      correct: correct,
      timeTaken: timeTaken,
    );
    await db.upsertProgress(updated);
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
      _questionStart = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildResults();

    final q = _current;
    final total = widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('السؤال ${_index + 1} من $total'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: total == 0 ? 0 : (_index) / total,
              backgroundColor: Colors.deepPurple.shade100,
              color: Colors.deepPurple,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPromptCard(q),
                    const SizedBox(height: 20),
                    if (q.optionsAreImages)
                      _buildImageOptions(q)
                    else
                      _buildTextOptions(q),
                    const SizedBox(height: 16),
                    if (_answered) _buildFeedback(q),
                  ],
                ),
              ),
            ),
            if (_answered) _buildNextBar(total),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(QuizQuestion q) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              q.promptAr,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (q.promptDetail != null) ...[
              const SizedBox(height: 14),
              Text(
                q.promptDetail!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ],
            if (q.audioUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _playAudio(q.audioUrl!),
                icon: const Icon(Icons.volume_up),
                label: const Text('استمع للنطق'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextOptions(QuizQuestion q) {
    final isArabicOptions = q.type == QuizType.chooseMeaning ||
        q.type == QuizType.listenChoose;
    return Column(
      children: q.options.map((option) {
        final color = _optionColor(option);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: color.background,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _onSelect(option),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    if (color.icon != null) ...[
                      Icon(color.icon, color: color.border, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        option.text ?? '',
                        textDirection: isArabicOptions
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 17,
                          color: color.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageOptions(QuizQuestion q) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: q.options.map((option) {
        final color = _optionColor(option);
        return GestureDetector(
          onTap: () => _onSelect(option),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.border, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: option.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  if (color.icon != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: color.border,
                        child: Icon(color.icon, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedback(QuizQuestion q) {
    final correct = _selected?.isCorrect ?? false;
    final correctText = q.options
        .firstWhere((o) => o.isCorrect)
        .text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: correct ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.cancel,
            color: correct ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correct
                  ? 'إجابة صحيحة! أحسنت 🎉'
                  : 'الإجابة الصحيحة: ${correctText ?? q.word.word}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: correct ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextBar(int total) {
    final isLast = _index == total - 1;
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isLast ? 'إنهاء الجلسة' : 'السؤال التالي',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ==================== شاشة النتائج ====================

  Widget _buildResults() {
    final total = widget.questions.length;
    final pct = total == 0 ? 0 : (_correctCount / total * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة الجلسة'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(
                pct >= 70 ? Icons.emoji_events : Icons.school,
                size: 90,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                '$_correctCount / $total إجابة صحيحة',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نسبة النجاح: %$pct',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              if (_hardWords.isNotEmpty) _buildHardWordsCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'العودة للرئيسية',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHardWordsCard() {
    // كلمات فريدة أخطأ فيها المستخدم.
    final unique = <String, Word>{};
    for (final w in _hardWords) {
      unique[w.word] = w;
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text(
                  'كلمات تحتاج مراجعة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unique.values.map((w) {
                return Chip(
                  label: Text('${w.word} — ${w.translation}'),
                  backgroundColor: Colors.red.shade50,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  _OptionColors _optionColor(QuizOption option) {
    if (!_answered) {
      return _OptionColors(
        background: Colors.white,
        border: Colors.deepPurple.shade100,
        text: Colors.black87,
      );
    }
    if (option.isCorrect) {
      return _OptionColors(
        background: Colors.green.shade50,
        border: Colors.green.shade600,
        text: Colors.green.shade900,
        icon: Icons.check,
      );
    }
    if (identical(option, _selected)) {
      return _OptionColors(
        background: Colors.red.shade50,
        border: Colors.red.shade600,
        text: Colors.red.shade900,
        icon: Icons.close,
      );
    }
    return _OptionColors(
      background: Colors.white,
      border: Colors.grey.shade300,
      text: Colors.grey.shade600,
    );
  }
}

class _OptionColors {
  final Color background;
  final Color border;
  final Color text;
  final IconData? icon;

  _OptionColors({
    required this.background,
    required this.border,
    required this.text,
    this.icon,
  });
}
