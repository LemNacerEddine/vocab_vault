import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../database/database_helper.dart';
import '../models/quiz_question.dart';
import '../models/word_progress.dart';
import '../services/mastery_service.dart';
import '../utils/question_type_labels.dart';

/// شاشة جلسة اختبار: تعرض الأسئلة تباعاً (بأنواعها العشرة المختلفة)،
/// تصحّح فورياً، وتحدّث جدولة "مستوى الإتقان" لكل كلمة.
class QuizScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizScreen({super.key, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  static final RegExp _arabicPattern = RegExp(r'[؀-ۿ]');

  int _index = 0;
  String? _selectedOption;
  bool _answered = false;
  int _correctCount = 0;
  final List<QuizQuestion> _wrongQuestions = [];

  QuizQuestion get _current => widget.questions[_index];
  bool get _isFinished => _index >= widget.questions.length;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  bool _isArabicText(String s) => _arabicPattern.hasMatch(s);

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

  Future<void> _onSelect(String option) async {
    if (_answered) return;
    final correct = option.trim() == _current.correctAnswer.trim();

    setState(() {
      _selectedOption = option;
      _answered = true;
      if (correct) {
        _correctCount++;
      } else {
        _wrongQuestions.add(_current);
      }
    });

    await _persistResult(_current, correct);
  }

  Future<void> _persistResult(QuizQuestion question, bool correct) async {
    final db = DatabaseHelper.instance;
    final current =
        await db.getProgress(question.wordId) ?? WordProgress.initial(question.wordId);
    final updated = MasteryService.applyAnswer(
      current,
      type: question.type,
      correct: correct,
    );
    await db.upsertProgress(updated);
  }

  void _next() {
    setState(() {
      _index++;
      _selectedOption = null;
      _answered = false;
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
              value: total == 0 ? 0 : _index / total,
              backgroundColor: Colors.deepPurple.shade100,
              color: Colors.deepPurple,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTypeChip(q),
                    const SizedBox(height: 10),
                    _buildPromptCard(q),
                    const SizedBox(height: 20),
                    _buildOptions(q),
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

  Widget _buildTypeChip(QuizQuestion q) {
    return Align(
      alignment: Alignment.center,
      child: Chip(
        avatar: Icon(QuestionTypeLabels.icon(q.type), size: 16, color: Colors.deepPurple),
        label: Text(QuestionTypeLabels.arabic(q.type)),
        backgroundColor: Colors.deepPurple.shade50,
        labelStyle: TextStyle(color: Colors.deepPurple.shade700, fontSize: 12),
      ),
    );
  }

  Widget _buildPromptCard(QuizQuestion q) {
    final hasImage = q.imageUrl != null && q.imageUrl!.isNotEmpty;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: q.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              q.prompt,
              textAlign: TextAlign.center,
              textDirection: _isArabicText(q.prompt) ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, height: 1.5),
            ),
            if (q.hint != null) ...[
              const SizedBox(height: 10),
              Text(
                q.hint!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(QuizQuestion q) {
    return Column(
      children: q.options.map((option) {
        final color = _optionColor(option, q);
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        option,
                        textDirection: _isArabicText(option) ? TextDirection.rtl : TextDirection.ltr,
                        style: TextStyle(fontSize: 16, color: color.text, fontWeight: FontWeight.w500),
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

  Widget _buildFeedback(QuizQuestion q) {
    final correct = _selectedOption?.trim() == q.correctAnswer.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: correct ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.cancel,
            color: correct ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? 'إجابة صحيحة! أحسنت 🎉' : 'الإجابة الصحيحة: ${q.correctAnswer}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: correct ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                if (q.explanation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    q.explanation!,
                    textDirection:
                        _isArabicText(q.explanation!) ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('نسبة النجاح: %$pct', style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              if (_wrongQuestions.isNotEmpty) _buildHardWordsCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'العودة للرئيسية',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
    // أسئلة فريدة أخطأ فيها المستخدم (كلمة + نوع السؤال).
    final unique = <String, QuizQuestion>{};
    for (final q in _wrongQuestions) {
      unique['${q.wordId}_${q.type.name}'] = q;
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
                const Text('نقاط تحتاج مراجعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unique.values.map((q) {
                return Chip(
                  avatar: Icon(QuestionTypeLabels.icon(q.type), size: 16, color: Colors.red.shade700),
                  label: Text('${q.correctAnswer} — ${QuestionTypeLabels.arabic(q.type)}'),
                  backgroundColor: Colors.red.shade50,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  _OptionColors _optionColor(String option, QuizQuestion q) {
    if (!_answered) {
      return _OptionColors(
        background: Colors.white,
        border: Colors.deepPurple.shade100,
        text: Colors.black87,
      );
    }
    final isCorrectOption = option.trim() == q.correctAnswer.trim();
    if (isCorrectOption) {
      return _OptionColors(
        background: Colors.green.shade50,
        border: Colors.green.shade600,
        text: Colors.green.shade900,
        icon: Icons.check,
      );
    }
    if (option == _selectedOption) {
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

  _OptionColors({required this.background, required this.border, required this.text, this.icon});
}
