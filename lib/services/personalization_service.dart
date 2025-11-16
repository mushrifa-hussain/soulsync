class PersonalizationService {
  static final PersonalizationService _instance = PersonalizationService._internal();
  factory PersonalizationService() => _instance;
  PersonalizationService._internal();

  // Store user answers in memory
  final List<String> _answers = [];

  // Getters
  List<String> get answers => _answers;
  
  // Methods
  void addAnswer(String answer) {
    _answers.add(answer);
  }

  void setAnswer(int index, String answer) {
    // Ensure list is large enough
    while (_answers.length <= index) {
      _answers.add('');
    }
    _answers[index] = answer;
  }

  void removeAnswersFrom(int startIndex) {
    if (startIndex < _answers.length) {
      _answers.removeRange(startIndex, _answers.length);
    }
  }

  void clearAnswers() {
    _answers.clear();
  }

  bool get isComplete => _answers.length >= 3;

  String? getAnswer(int index) {
    if (index >= 0 && index < _answers.length) {
      return _answers[index].isEmpty ? null : _answers[index];
    }
    return null;
  }
}

