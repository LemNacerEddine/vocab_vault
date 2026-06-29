# الخطة الشاملة والمعمقة لتطبيق Flutter لتعليم اللغة الإنجليزية (Offline-First)
## مع أمثلة عملية وتفاصيل تقنية دقيقة

---

## الجزء الأول: الفهم العميق للفكرة

### 1.1 الفكرة الأساسية والمشكلة التي تحلها

**المشكلة:** معظم تطبيقات تعليم اللغات تقدم كلمات عامة قد لا تكون ذات صلة بحياة المستخدم اليومية. بالإضافة إلى ذلك، تعتمد على الإنترنت بشكل مستمر، وتقدم الكلمات بطرق رتيبة (فقط نص وترجمة).

**الحل:** تطبيق يسمح للمستخدم بإضافة الكلمات التي يصادفها في حياته الفعلية، ثم يقوم التطبيق بجلب كل ما يتعلق بتلك الكلمة (صور، صوت، فيديو، أمثلة) في لحظة الإضافة. بعد ذلك، يعمل التطبيق بدون إنترنت تماماً، ويقدم الكلمة بطرق متنوعة وممتعة.

### 1.2 مثال واقعي لسير العمل

**السيناريو:**
- المستخدم يقرأ مقالة عن الاقتصاد ويصادف كلمة "Recession" لا يعرفها.
- يفتح التطبيق (متصل بالإنترنت) ويكتب الكلمة.
- في ثانية واحدة، يجلب التطبيق:
    - المعنى: "فترة من الانكماش الاقتصادي"
    - النطق الصوتي: ملف MP3 من قاموس Oxford
    - صور: ثلاث صور توضيحية من Unsplash (مثلاً: رسوم بيانية هابطة)
    - أمثلة: "The country faced a severe recession in 2008"
    - فيديو: مقطع 5 ثوانٍ من فيلم أو خطاب يستخدم الكلمة
- تُحفظ كل هذه البيانات محلياً على الجهاز.
- بعد ساعة، يرسل التطبيق إشعاراً: "حان وقت مراجعة كلمة Recession!"
- يفتح المستخدم التطبيق (بدون إنترنت) ويرى سؤالاً مثل:
    - "اختر الصورة التي تعبر عن Recession" (مع ثلاث صور)
    - أو: "استمع للنطق وأكمل الجملة: The country faced a severe ______"
    - أو: "شاهد الفيديو واختر: هل الكلمة تعني أ) نمو اقتصادي أم ب) انكماش اقتصادي؟"

---

## الجزء الثاني: بنية قاعدة البيانات (Database Schema)

### 2.1 الجداول الأساسية

#### جدول `Words` (الكلمات الرئيسية)
```
CREATE TABLE words (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word TEXT UNIQUE NOT NULL,
  translation TEXT NOT NULL,
  partOfSpeech TEXT,  -- noun, verb, adjective, etc.
  level TEXT,  -- beginner, intermediate, advanced
  definition TEXT,  -- التعريف الكامل
  
  -- متغيرات خوارزمية SM-2
  nextReviewDate DATETIME,  -- موعد المراجعة القادم
  interval INTEGER DEFAULT 1,  -- عدد الأيام حتى المراجعة القادمة
  repetition INTEGER DEFAULT 0,  -- عدد الإجابات الصحيحة المتتالية
  easeFactor REAL DEFAULT 2.5,  -- معامل السهولة (يبدأ بـ 2.5)
  
  -- إحصائيات
  totalAttempts INTEGER DEFAULT 0,  -- عدد محاولات الإجابة
  correctAttempts INTEGER DEFAULT 0,  -- عدد الإجابات الصحيحة
  lastReviewDate DATETIME,  -- آخر مراجعة
  
  -- البيانات الوصفية
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  userLevel TEXT  -- المستوى الذي أضاف الكلمة
);
```

#### جدول `Media` (الوسائط: صور، صوت، فيديو)
```
CREATE TABLE media (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wordId INTEGER NOT NULL,
  mediaType TEXT NOT NULL,  -- 'image', 'audio', 'video'
  localPath TEXT NOT NULL,  -- المسار المحلي على الجهاز
  remoteUrl TEXT,  -- الرابط الأصلي (للمرجعية)
  fileName TEXT,  -- اسم الملف
  fileSizeKB INTEGER,  -- حجم الملف بـ KB
  downloadedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (wordId) REFERENCES words(id) ON DELETE CASCADE
);
```

#### جدول `Examples` (الأمثلة والجمل)
```
CREATE TABLE examples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wordId INTEGER NOT NULL,
  sentence TEXT NOT NULL,  -- الجملة بالإنجليزية
  translation TEXT NOT NULL,  -- ترجمة الجملة
  source TEXT,  -- مصدر الجملة (كتاب، فيلم، إلخ)
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (wordId) REFERENCES words(id) ON DELETE CASCADE
);
```

#### جدول `ReviewHistory` (سجل المراجعات)
```
CREATE TABLE reviewHistory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wordId INTEGER NOT NULL,
  questionType TEXT,  -- 'multiple_choice', 'fill_blank', 'audio', 'image', 'video'
  isCorrect BOOLEAN,
  userAnswer TEXT,
  correctAnswer TEXT,
  reviewedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  timeSpentSeconds INTEGER,  -- الوقت المستغرق للإجابة
  
  FOREIGN KEY (wordId) REFERENCES words(id) ON DELETE CASCADE
);
```

#### جدول `ScheduledNotifications` (الإشعارات المجدولة)
```
CREATE TABLE scheduledNotifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wordId INTEGER NOT NULL,
  scheduledTime DATETIME NOT NULL,
  notificationId INTEGER UNIQUE,  -- معرّف الإشعار في نظام التشغيل
  isSent BOOLEAN DEFAULT FALSE,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (wordId) REFERENCES words(id) ON DELETE CASCADE
);
```

### 2.2 مثال عملي لبيانات في قاعدة البيانات

**بعد إضافة كلمة "Resilient":**

| جدول | البيانات |
|------|---------|
| **words** | id=1, word="Resilient", translation="قادر على التكيف والتعافي", level="intermediate", nextReviewDate="2024-06-25 14:00", interval=1, repetition=0, easeFactor=2.5 |
| **media** | id=1, wordId=1, mediaType="audio", localPath="/data/user/0/com.app/resilient.mp3", fileName="resilient.mp3" |
| **media** | id=2, wordId=1, mediaType="image", localPath="/data/user/0/com.app/resilient_1.jpg", fileName="resilient_1.jpg" |
| **media** | id=3, wordId=1, mediaType="video", localPath="/data/user/0/com.app/resilient_clip.mp4", fileName="resilient_clip.mp4" |
| **examples** | id=1, wordId=1, sentence="She is resilient and never gives up", translation="إنها قادرة على التكيف ولا تستسلم أبداً" |
| **examples** | id=2, wordId=1, sentence="The team showed resilience after the loss", translation="أظهر الفريق قدرة على التعافي بعد الخسارة" |
| **scheduledNotifications** | id=1, wordId=1, scheduledTime="2024-06-25 14:00", notificationId=101 |

---

## الجزء الثالث: واجهات برمجة التطبيقات (APIs) المستخدمة

### 3.1 جلب المعاني والنطق الصوتي

**API المستخدم:** Free Dictionary API (https://dictionaryapi.dev/)

**مثال على الطلب:**
```
GET https://api.dictionaryapi.dev/api/v2/entries/english/resilient
```

**الاستجابة (JSON):**
```json
[
  {
    "word": "resilient",
    "phonetic": "/rɪˈzɪl.jənt/",
    "phonetics": [
      {
        "text": "/rɪˈzɪl.jənt/",
        "audio": "https://media.githubusercontent.com/media/free-dictionary-api/dictionary/main/server/public/audio/resilient.mp3"
      }
    ],
    "meanings": [
      {
        "partOfSpeech": "adjective",
        "definitions": [
          {
            "definition": "Able to withstand or recover quickly from difficult conditions",
            "example": "The resilient nature of the human spirit"
          }
        ]
      }
    ]
  }
]
```

**ما يفعله التطبيق:**
1. يستخرج الـ `audio` URL ويحمل الملف.
2. يحفظ الملف محلياً في `path_provider`.
3. يستخرج `definition` و `example` ويحفظهما في قاعدة البيانات.

### 3.2 جلب الصور التوضيحية

**API المستخدم:** Unsplash API (https://unsplash.com/developers)

**مثال على الطلب:**
```
GET https://api.unsplash.com/search/photos?query=resilient&per_page=3&client_id=YOUR_CLIENT_ID
```

**الاستجابة (JSON مختصرة):**
```json
{
  "results": [
    {
      "id": "abc123",
      "urls": {
        "small": "https://images.unsplash.com/photo-abc123?w=400",
        "regular": "https://images.unsplash.com/photo-abc123?w=1080"
      }
    }
  ]
}
```

**ما يفعله التطبيق:**
1. يحمل الصور (عادة 2-3 صور).
2. يحفظها محلياً.
3. يربطها بالكلمة في جدول `media`.

### 3.3 جلب مقاطع الفيديو (السياق الحي)

**الخيار الأول:** YouTube Data API (معقد قليلاً)
```
GET https://www.googleapis.com/youtube/v3/search?q=resilient&maxResults=1&key=YOUR_API_KEY
```

**الخيار الأفضل:** استخدام خدمة متخصصة مثل **YouGlish** (إن توفرت) أو **PlayPhrase.me** (عبر Web Scraping).

**بديل بسيط:** جلب مقاطع من YouTube مباشرة وتحميلها (مع احترام حقوق النشر).

---

## الجزء الرابع: حزم Flutter المستخدمة (Dependencies)

### 4.1 حزم قاعدة البيانات والتخزين المحلي

```yaml
dependencies:
  isar: ^3.1.0  # قاعدة بيانات محلية سريعة جداً
  isar_flutter_libs: ^3.1.0
  path_provider: ^2.0.0  # للوصول إلى مسارات التخزين المحلي
  dio: ^5.0.0  # لتحميل الملفات
  flutter_local_notifications: ^15.0.0  # الإشعارات المحلية
  flutter_tts: ^0.13.0  # تحويل النص إلى كلام
  speech_to_text: ^6.0.0  # تحويل الكلام إلى نص
  video_player: ^2.0.0  # تشغيل الفيديوهات المحلية
  cached_network_image: ^3.0.0  # تخزين الصور مؤقتاً
  http: ^1.0.0  # لطلبات HTTP البسيطة
  json_serializable: ^6.0.0  # تسلسل JSON
```

### 4.2 حزم الواجهة والتصميم

```yaml
dependencies:
  flutter_riverpod: ^2.0.0  # إدارة الحالة (State Management)
  get_it: ^7.0.0  # Dependency Injection
  flutter_screenutil: ^5.0.0  # تصميم مستجيب
  animations: ^2.0.0  # رسوم متحركة جميلة
  lottie: ^2.0.0  # رسوم متحركة Lottie
```

---

## الجزء الخامس: خوارزمية التعلم المتكرر (SM-2 Algorithm)

### 5.1 شرح الخوارزمية

خوارزمية SM-2 تحسب الفترة الزمنية المثالية لمراجعة المعلومة قبل نسيانها. تعتمد على ثلاثة متغيرات:

1. **EaseFactor (EF):** معامل السهولة (يبدأ بـ 2.5)
2. **Interval (I):** عدد الأيام حتى المراجعة القادمة
3. **Repetition (R):** عدد الإجابات الصحيحة المتتالية

### 5.2 الصيغة الرياضية

```
إذا كانت الإجابة صحيحة:
  EF' = EF + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
  إذا كانت R = 0:
    I = 1
  إذا كانت R = 1:
    I = 3
  وإلا:
    I = I * EF
  R = R + 1

إذا كانت الإجابة خاطئة:
  R = 0
  I = 1
```

حيث `quality` هو تقييم من 0-5 (0 = خطأ تام، 5 = إجابة مثالية).

### 5.3 مثال عملي

**الكلمة: "Resilient"**

| المراجعة | التقييم | EF | Interval | NextReview |
|---------|--------|-----|----------|-----------|
| الأولى | 5 | 2.6 | 1 | غداً |
| الثانية | 5 | 2.7 | 3 | بعد 3 أيام |
| الثالثة | 4 | 2.7 | 8 | بعد 8 أيام |
| الرابعة | 5 | 2.8 | 22 | بعد 22 يوماً |

### 5.4 كود Dart لتطبيق الخوارزمية

```dart
class SpacedRepetitionEngine {
  static const double minEaseFactor = 1.3;
  
  static Map<String, dynamic> calculateNextReview(
    int quality,  // 0-5
    double currentEF,
    int currentInterval,
    int currentRepetition,
  ) {
    double newEF = currentEF + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEF = newEF < minEaseFactor ? minEaseFactor : newEF;
    
    int newInterval;
    int newRepetition;
    
    if (quality < 3) {
      // الإجابة خاطئة
      newRepetition = 0;
      newInterval = 1;
    } else {
      // الإجابة صحيحة
      newRepetition = currentRepetition + 1;
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 3;
      } else {
        newInterval = (currentInterval * newEF).round();
      }
    }
    
    DateTime nextReviewDate = DateTime.now().add(Duration(days: newInterval));
    
    return {
      'easeFactor': newEF,
      'interval': newInterval,
      'repetition': newRepetition,
      'nextReviewDate': nextReviewDate,
    };
  }
}
```

---

## الجزء السادس: نظام الإشعارات المحلية

### 6.1 جدولة الإشعارات

عندما ينتهي المستخدم من الإجابة على كلمة، يتم حساب موعد المراجعة القادم وجدولة إشعار محلي.

```dart
Future<void> scheduleReviewNotification(Word word, DateTime nextReviewDate) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  await flutterLocalNotificationsPlugin.zonedSchedule(
    word.id,
    'حان وقت المراجعة! 📚',
    'هل تتذكر معنى كلمة "${word.word}"؟',
    tz.TZDateTime.from(nextReviewDate, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'vocabulary_channel',
        'Vocabulary Review',
        channelDescription: 'Notifications for vocabulary review',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}
```

### 6.2 التعامل مع النقر على الإشعار

```dart
void initializeNotifications() {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // عند النقر على الإشعار، فتح التطبيق وعرض سؤال الكلمة
      int wordId = int.parse(response.id ?? '0');
      navigateToReviewScreen(wordId);
    },
  );
}
```

---

## الجزء السابع: أنواع الأسئلة وتوليدها ديناميكياً

### 7.1 نوع السؤال الأول: اختيار من متعدد (Multiple Choice)

```dart
class MultipleChoiceQuestion {
  final Word correctWord;
  final List<Word> options;  // 4 خيارات (1 صحيح + 3 خاطئة)
  
  MultipleChoiceQuestion({
    required this.correctWord,
    required this.options,
  });
  
  static MultipleChoiceQuestion generate(Word word, List<Word> allWords) {
    // اختيار 3 كلمات عشوائية كخيارات خاطئة
    final wrongOptions = allWords
        .where((w) => w.id != word.id)
        .toList()
        ..shuffle();
    
    final options = [word, ...wrongOptions.take(3)]..shuffle();
    
    return MultipleChoiceQuestion(
      correctWord: word,
      options: options,
    );
  }
}

// عرض السؤال
class MultipleChoiceQuestionWidget extends StatelessWidget {
  final MultipleChoiceQuestion question;
  final Function(bool) onAnswered;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('اختر معنى الكلمة: ${question.correctWord.word}'),
        ...question.options.map((option) => ElevatedButton(
          onPressed: () {
            bool isCorrect = option.id == question.correctWord.id;
            onAnswered(isCorrect);
          },
          child: Text(option.translation),
        )),
      ],
    );
  }
}
```

### 7.2 نوع السؤال الثاني: ملء الفراغات (Fill in the Blank)

```dart
class FillBlankQuestion {
  final Example example;
  final Word word;
  
  FillBlankQuestion({required this.example, required this.word});
  
  static FillBlankQuestion generate(Word word, List<Example> examples) {
    final example = examples.firstWhere((e) => e.wordId == word.id);
    return FillBlankQuestion(example: example, word: word);
  }
}

// عرض السؤال
class FillBlankQuestionWidget extends StatefulWidget {
  final FillBlankQuestion question;
  final Function(bool) onAnswered;
  
  @override
  State<FillBlankQuestionWidget> createState() => _FillBlankQuestionWidgetState();
}

class _FillBlankQuestionWidgetState extends State<FillBlankQuestionWidget> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }
  
  @override
  Widget build(BuildContext context) {
    final sentence = widget.question.example.sentence
        .replaceAll(widget.question.word.word, '______');
    
    return Column(
      children: [
        Text('أكمل الجملة: $sentence'),
        TextField(controller: _controller),
        ElevatedButton(
          onPressed: () {
            bool isCorrect = _controller.text.toLowerCase() ==
                widget.question.word.word.toLowerCase();
            widget.onAnswered(isCorrect);
          },
          child: Text('تحقق'),
        ),
      ],
    );
  }
}
```

### 7.3 نوع السؤال الثالث: الاستماع والنطق (Audio & Pronunciation)

```dart
class AudioQuestion {
  final Word word;
  final String audioPath;
  
  AudioQuestion({required this.word, required this.audioPath});
}

// عرض السؤال
class AudioQuestionWidget extends StatefulWidget {
  final AudioQuestion question;
  final Function(bool) onAnswered;
  
  @override
  State<AudioQuestionWidget> createState() => _AudioQuestionWidgetState();
}

class _AudioQuestionWidgetState extends State<AudioQuestionWidget> {
  late AudioPlayer _audioPlayer;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('استمع للكلمة واختر معناها'),
        ElevatedButton(
          onPressed: () {
            _audioPlayer.play(DeviceFileSource(widget.question.audioPath));
          },
          child: Text('▶ استمع'),
        ),
        ...['معنى 1', 'معنى 2', 'معنى 3'].map((meaning) => ElevatedButton(
          onPressed: () {
            widget.onAnswered(meaning == 'معنى 1');  // مثال
          },
          child: Text(meaning),
        )),
      ],
    );
  }
}
```

### 7.4 نوع السؤال الرابع: الصورة (Image Recognition)

```dart
class ImageQuestion {
  final Word word;
  final List<String> imagePaths;
  final int correctImageIndex;
  
  ImageQuestion({
    required this.word,
    required this.imagePaths,
    required this.correctImageIndex,
  });
}

// عرض السؤال
class ImageQuestionWidget extends StatelessWidget {
  final ImageQuestion question;
  final Function(bool) onAnswered;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('اختر الصورة التي تعبر عن: ${question.word.word}'),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
          itemCount: question.imagePaths.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                bool isCorrect = index == question.correctImageIndex;
                onAnswered(isCorrect);
              },
              child: Image.file(File(question.imagePaths[index])),
            );
          },
        ),
      ],
    );
  }
}
```

---

## الجزء الثامن: خطة التطوير المرحلية (Development Roadmap)

### المرحلة 1: الإعداد والتصميم (أسبوع واحد)
- إنشاء مشروع Flutter جديد.
- تصميم واجهات المستخدم (Figma).
- إعداد البنية الأساسية للمشروع.

### المرحلة 2: قاعدة البيانات (أسبوع واحد)
- دمج Isar وإنشاء الجداول.
- برمجة العمليات الأساسية (CRUD).
- اختبار قاعدة البيانات.

### المرحلة 3: جلب البيانات من APIs (أسبوع واحد)
- دمج Free Dictionary API.
- دمج Unsplash API.
- برمجة نظام تحميل الملفات.

### المرحلة 4: الخوارزمية والإشعارات (أسبوع واحد)
- برمجة خوارزمية SM-2.
- دمج flutter_local_notifications.
- اختبار الإشعارات.

### المرحلة 5: الواجهات والأسئلة (أسبوعان)
- برمجة شاشات الأسئلة المختلفة.
- دمج الصوت والفيديو.
- اختبار الواجهات.

### المرحلة 6: الاختبار والإطلاق (أسبوع واحد)
- اختبار شامل على أجهزة حقيقية.
- تحسين الأداء.
- رفع على App Store و Google Play.

---

## الخلاصة

هذا التطبيق يمثل **منصة تعليمية ذكية وشاملة** تجمع بين:
- **التخصيص:** كلمات من اختيار المستخدم نفسه.
- **الغنى:** صور، صوت، فيديو، أمثلة.
- **الذكاء:** خوارزمية SM-2 لتحديد أفضل وقت للمراجعة.
- **الاستقلالية:** عمل كامل بدون إنترنت بعد تحميل البيانات.
- **الممتعة:** أسئلة متنوعة وإشعارات تحفيزية.

استخدام Flutter يضمن أن التطبيق سيعمل بسلاسة على Android و iOS بكود واحد، مما يوفر الوقت والجهد في التطوير والصيانة.
##--------------------------------------------------------------------------
##



# خطة تنفيذ وتطوير تطبيق "VocabVault" (التطوير التدريجي)

يعتمد هذا النهج على بناء التطبيق خطوة بخطوة (Iterative Development). نبدأ بنسخة أساسية جداً (MVP) لضمان عمل الكود الأساسي بدون أخطاء، ثم نضيف الميزات تدريجياً.

---

## المرحلة 1: النسخة الأساسية جداً (MVP - Minimum Viable Product)
**الهدف:** تطبيق بسيط جداً يضيف الكلمات ويحفظها محلياً ويعرضها في قائمة.

| الخطوة | التفاصيل التقنية | النتيجة المتوقعة |
|--------|------------------|------------------|
| **1. إنشاء المشروع** | `flutter create vocab_vault` | مشروع Flutter جديد يعمل بدون أخطاء. |
| **2. إعداد قاعدة البيانات** | إضافة حزمة `sqflite` أو `hive`. إنشاء جدول بسيط `Words` (ID, Word, Translation). | القدرة على حفظ البيانات محلياً. |
| **3. واجهة الإضافة** | شاشة تحتوي على حقلين (الكلمة بالإنجليزية، الترجمة بالعربية) وزر "حفظ". | المستخدم يكتب الكلمة وترجمتها يدوياً وتحفظ. |
| **4. واجهة العرض** | شاشة رئيسية تعرض قائمة (ListView) بجميع الكلمات المحفوظة. | المستخدم يرى الكلمات التي أضافها. |

**نهاية المرحلة 1:** تطبيق يعمل كدفتر ملاحظات بسيط للكلمات، بدون إنترنت وبدون أي ذكاء.

---

## المرحلة 2: دمج واجهات برمجة التطبيقات (APIs) الأساسية
**الهدف:** جعل التطبيق ذكياً في جلب المعاني بدلاً من الإدخال اليدوي.

| الخطوة | التفاصيل التقنية | النتيجة المتوقعة |
|--------|------------------|------------------|
| **1. دمج Dictionary API** | إضافة حزمة `http`. برمجة دالة لجلب المعنى والأمثلة من API. | عند كتابة كلمة، يتم جلب معناها بالإنجليزية وأمثلة عليها. |
| **2. تحديث قاعدة البيانات** | إضافة أعمدة جديدة: Definition, Example. | حفظ المعنى الإنجليزي والمثال في القاعدة المحلية. |
| **3. تحديث واجهة الإضافة** | المستخدم يكتب الكلمة فقط، ويضغط "بحث"، فيعرض التطبيق المعنى والمثال للحفظ. | أتمتة عملية جلب المعاني وتقليل الجهد. |
| **4. تحديث واجهة العرض** | عند الضغط على كلمة في القائمة، تفتح شاشة تفاصيل تعرض المعنى والمثال. | عرض التفاصيل الغنية للكلمة. |

**نهاية المرحلة 2:** تطبيق يجلب المعاني والأمثلة تلقائياً ويحفظها.

---

## المرحلة 3: دمج الوسائط المتعددة (الصوت والصور)
**الهدف:** إضافة النطق الصوتي والصور التوضيحية لترسيخ الحفظ.

| الخطوة | التفاصيل التقنية | النتيجة المتوقعة |
|--------|------------------|------------------|
| **1. دمج النطق الصوتي** | إضافة حزمة `audioplayers`. جلب رابط الصوت من Dictionary API وتشغيله. | زر بجانب الكلمة لسماع نطقها. |
| **2. دمج Unsplash API** | جلب روابط 3 صور للكلمة من Unsplash API. | عرض صور توضيحية للكلمة في شاشة التفاصيل. |
| **3. التخزين المحلي للوسائط** | إضافة حزمة `path_provider` و `dio`. تحميل الصوت والصور وحفظها في الهاتف. | التطبيق يعمل بدون إنترنت مع عرض الصور وتشغيل الصوت. |

**نهاية المرحلة 3:** تطبيق غني بالوسائط يعمل بالكامل (Offline) بعد مرحلة الإضافة.

---

## المرحلة 4: خوارزمية التعلم والأسئلة (Spaced Repetition)
**الهدف:** تحويل التطبيق من "قاموس" إلى "معلم" يختبر المستخدم.

| الخطوة | التفاصيل التقنية | النتيجة المتوقعة |
|--------|------------------|------------------|
| **1. برمجة الخوارزمية** | تحديث قاعدة البيانات بمتغيرات (Interval, EaseFactor). كتابة دالة خوارزمية SM-2. | تحديد متى يجب مراجعة كل كلمة. |
| **2. شاشة الأسئلة الأساسية** | إنشاء سؤال "اختيار من متعدد" (نصي). | المستخدم يختار المعنى الصحيح من 4 خيارات. |
| **3. تحديث البيانات** | عند الإجابة، تحديث متغيرات الكلمة بناءً على صحة الإجابة. | الكلمات الصعبة تظهر قريباً، والسهلة تتباعد. |
| **4. تنويع الأسئلة** | إضافة أسئلة تعتمد على الصوت (استمع واختر) والصور (شاهد واختر). | تجربة تعلم ممتعة وغير رتيبة. |

**نهاية المرحلة 4:** تطبيق ذكي يختبر المستخدم بطرق متنوعة ويحسب وقت المراجعة.

---

## المرحلة 5: الإشعارات والتحسينات النهائية
**الهدف:** تذكير المستخدم بمواعيد المراجعة وتحسين تجربة الاستخدام.

| الخطوة | التفاصيل التقنية | النتيجة المتوقعة |
|--------|------------------|------------------|
| **1. الإشعارات المحلية** | إضافة حزمة `flutter_local_notifications`. جدولة إشعار بناءً على وقت المراجعة. | التطبيق يرسل تنبيهاً للمستخدم (بدون إنترنت). |
| **2. تحسين واجهة المستخدم** | إضافة رسوم متحركة، ألوان جذابة، وأيقونات مخصصة. | تطبيق ذو مظهر احترافي ومريح للعين. |
| **3. إحصائيات المستخدم** | شاشة تعرض عدد الكلمات المحفوظة ومستوى التقدم. | تحفيز المستخدم للاستمرار في التعلم. |
| **4. الاختبار الشامل** | تجربة التطبيق على أجهزة حقيقية ومعالجة أي أخطاء (Bugs). | تطبيق مستقر وجاهز للاستخدام. |

**نهاية المرحلة 5:** تطبيق متكامل، ذكي، تفاعلي، وجاهز للنشر!

---

## كيف نبدأ الآن؟

سنبدأ فوراً بـ **المرحلة 1**.
سأقوم بتجهيز الكود الأساسي لإنشاء المشروع وقاعدة البيانات البسيطة (MVP) لكي تقوم بتشغيلها والتأكد من أنها تعمل بدون أي مشاكل قبل الانتقال للمرحلة التالية.
