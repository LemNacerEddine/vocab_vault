import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';
import '../services/unsplash_service.dart';
import '../services/translation_service.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();

  bool _isSaving = false;
  bool _isSearching = false;
  DictionaryResult? _dictionaryResult;
  List<UnsplashImage> _images = [];
  UnsplashImage? _selectedImage;
  String? _searchError;
  bool _isTranslating = false;

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  // البحث عن الكلمة + جلب الصور + الترجمة التلقائية
  Future<void> _searchWord() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _searchError = 'الرجاء إدخال الكلمة أولاً');
      return;
    }

    final exists = await DatabaseHelper.instance.wordExists(word);
    if (exists) {
      setState(() => _searchError = 'هذه الكلمة موجودة مسبقاً في قائمتك!');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _dictionaryResult = null;
      _images = [];
      _selectedImage = null;
    });

    // جلب البيانات بالتوازي: القاموس + الصور + الترجمة
    final results = await Future.wait([
      DictionaryService.lookupWord(word),
      UnsplashService.searchImages(word),
      TranslationService.translateToArabic(word),
    ]);

    final dictResult = results[0] as DictionaryResult?;
    final imageResults = results[1] as List<UnsplashImage>;
    final translation = results[2] as String?;

    setState(() {
      _isSearching = false;
      _dictionaryResult = dictResult;
      _images = imageResults;

      if (imageResults.isNotEmpty) {
        _selectedImage = imageResults[0];
      }

      // ملء الترجمة تلقائياً
      if (translation != null && _translationController.text.isEmpty) {
        _translationController.text = translation;
      }

      if (dictResult == null && imageResults.isEmpty) {
        _searchError =
            'لم يتم العثور على الكلمة. تأكد من الإملاء أو اتصال الإنترنت.\nيمكنك حفظ الكلمة يدوياً بإدخال الترجمة والضغط على حفظ.';
      }
    });
  }

  // حفظ الكلمة في قاعدة البيانات
  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final word = Word(
      word: _wordController.text.trim(),
      translation: _translationController.text.trim(),
      definition: _dictionaryResult?.firstDefinition,
      allDefinitions: _dictionaryResult?.allDefinitionsText,
      example: _dictionaryResult?.firstExample,
      allExamples: _dictionaryResult?.allExamples.join('\n'),
      phonetic: _dictionaryResult?.phonetic,
      audioUrl: _dictionaryResult?.audioUrl,
      partOfSpeech: _dictionaryResult?.firstPartOfSpeech,
      allPartsOfSpeech:
          _dictionaryResult?.meanings.map((m) => m.partOfSpeech).join(', '),
      synonyms: _dictionaryResult?.allSynonyms.join(','),
      antonyms: _dictionaryResult?.allAntonyms.join(','),
      rootWord: _dictionaryResult?.rootWord,
      formTypeLabel: _dictionaryResult?.formTypeLabel,
      inputFormExamples: _dictionaryResult?.inputFormExamples.isNotEmpty == true
          ? _dictionaryResult!.inputFormExamples.join('\n')
          : null,
      imageUrl: _selectedImage?.regularUrl,
      imageDescription: _selectedImage?.description,
      allImageUrls: _images.isNotEmpty
          ? _images.map((img) => img.regularUrl).join('|')
          : null,
    );

    await DatabaseHelper.instance.insertWord(word);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ كلمة "${word.word}" بنجاح! ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة كلمة جديدة'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // حقل الكلمة بالإنجليزية مع زر البحث
                _buildSearchField(),
                const SizedBox(height: 8),

                // رسالة الخطأ
                if (_searchError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _searchError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),

                // نتيجة البحث من القاموس
                if (_dictionaryResult != null) ...[
                  const SizedBox(height: 12),
                  _buildDictionaryResultCard(),
                ],

                // المرادفات والأضداد
                if (_dictionaryResult != null &&
                    (_dictionaryResult!.allSynonyms.isNotEmpty ||
                        _dictionaryResult!.allAntonyms.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  _buildSynonymsAntonymsCard(),
                ],

                // عرض الصور من Unsplash
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildImageSelector(),
                ],

                const SizedBox(height: 16),

                // حقل الترجمة بالعربية
                _buildTranslationField(),
                const SizedBox(height: 24),

                // زر الحفظ
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // حقل البحث
  Widget _buildSearchField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _wordController,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: 'الكلمة بالإنجليزية',
              hintText: 'مثال: Resilient',
              prefixIcon: const Icon(Icons.abc, color: Colors.deepPurple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.deepPurple, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال الكلمة';
              }
              return null;
            },
            onFieldSubmitted: (_) => _searchWord(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 58,
          width: 58,
          child: ElevatedButton(
            onPressed: _isSearching ? null : _searchWord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
            ),
            child: _isSearching
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search, size: 28),
          ),
        ),
      ],
    );
  }

  // بطاقة نتيجة القاموس المحسنة
  Widget _buildDictionaryResultCard() {
    final result = _dictionaryResult!;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // بطاقة تنبيه الجذر (تظهر فقط إذا كانت الكلمة جمعاً أو متصرفة)
            if (result.isModifiedForm && result.rootWord != null) ...[  
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم الكشف عن صيغة: ${result.formTypeLabel ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 13, color: Colors.orange.shade900),
                        children: [
                          const TextSpan(text: 'الكلمة المدخلة «'),
                          TextSpan(
                            text: result.word,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic),
                          ),
                          const TextSpan(text: '» هي '),
                          TextSpan(
                            text: result.formTypeLabel ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' لـ «'),
                          TextSpan(
                            text: result.rootWord!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const TextSpan(
                              text:
                                  '». تم جلب معلومات الكلمة الأصلية مع دمج أمثلتها.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // العنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.check, color: Colors.green.shade700, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.rootWord != null && result.isModifiedForm
                        ? '${result.rootWord!} (${result.word})'
                        : result.word,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),

            // النطق الصوتي
            if (result.phonetic != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up,
                        size: 16, color: Colors.deepPurple.shade400),
                    const SizedBox(width: 6),
                    Text(
                      result.phonetic!,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // أنواع الكلمة
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.meanings.map((m) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPartOfSpeechColor(m.partOfSpeech)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPartOfSpeechColor(m.partOfSpeech)
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    m.partOfSpeech,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getPartOfSpeechColor(m.partOfSpeech),
                    ),
                  ),
                );
              }).toList(),
            ),

            const Divider(height: 24),

            // عرض المعاني (أول 3 تعريفات)
            ...result.meanings.take(2).map((meaning) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '(${meaning.partOfSpeech})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getPartOfSpeechColor(meaning.partOfSpeech),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...meaning.definitions.take(2).map((def) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  def.definition,
                                  style: const TextStyle(fontSize: 14),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                          if (def.example != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.format_quote,
                                      size: 14, color: Colors.amber.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      def.example!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade700,
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // بطاقة المرادفات والأضداد
  Widget _buildSynonymsAntonymsCard() {
    final result = _dictionaryResult!;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المرادفات
            if (result.allSynonyms.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.compare_arrows,
                      size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'المرادفات (Synonyms)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.allSynonyms.take(8).map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // فاصل بين المرادفات والأضداد
            if (result.allSynonyms.isNotEmpty &&
                result.allAntonyms.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],

            // الأضداد
            if (result.allAntonyms.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: 18, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'الأضداد (Antonyms)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.allAntonyms.take(8).map((a) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      a,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
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

  // عرض الصور من Unsplash
  Widget _buildImageSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.deepPurple.shade400),
                const SizedBox(width: 8),
                const Text(
                  'اختر صورة توضيحية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  final isSelected = _selectedImage?.id == image.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = isSelected ? null : image;
                      });
                    },
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey[300]!,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: image.smallUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image),
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.deepPurple.withOpacity(0.3),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 30,
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
            if (_selectedImage != null &&
                _selectedImage!.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedImage!.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // حقل الترجمة
  Widget _buildTranslationField() {
    return TextFormField(
      controller: _translationController,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'الترجمة بالعربية',
        hintText: 'ستُملأ تلقائياً أو أدخلها يدوياً',
        prefixIcon: const Icon(Icons.language, color: Colors.deepPurple),
        suffixIcon: _translationController.text.isNotEmpty
            ? Icon(Icons.auto_fix_high,
                color: Colors.green.shade400, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'الرجاء إدخال الترجمة';
        }
        return null;
      },
    );
  }

  // زر الحفظ
  Widget _buildSaveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveWord,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _isSaving ? 'جاري الحفظ...' : 'حفظ الكلمة',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  // ألوان حسب نوع الكلمة
  Color _getPartOfSpeechColor(String partOfSpeech) {
    switch (partOfSpeech.toLowerCase()) {
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
