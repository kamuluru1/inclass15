import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(QuizApp());
}

/// The root widget of the app.
class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
      routes: {
        '/quiz': (context) => QuizScreen(),
        '/result': (context) => ResultScreen(),
      },
    );
  }
}

/// HomeScreen: a simple screen with a “Start Quiz” button.
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trivia Quiz App'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text('Start Quiz'),
          onPressed: () {
            Navigator.pushNamed(context, '/quiz');
          },
        ),
      ),
    );
  }
}

/// Model class representing each quiz question.
class QuizQuestion {
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;

  QuizQuestion({
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
  });

  // Factory constructor to build a QuizQuestion from JSON.
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String,
      correctAnswer: json['correct_answer'] as String,
      // Convert incorrect_answers into a List<String>
      incorrectAnswers: List<String>.from(json['incorrect_answers'] as List),
    );
  }
}

/// QuizScreen: Fetches trivia questions from the API and displays them one by one.
class QuizScreen extends StatefulWidget {
  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> _futureQuestions;
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    _futureQuestions = fetchQuizQuestions();
  }

  /// Fetch 10 multiple choice questions from Open Trivia Database.
  Future<List<QuizQuestion>> fetchQuizQuestions() async {
    final url = Uri.parse('https://opentdb.com/api.php?amount=10&type=multiple');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((question) => QuizQuestion.fromJson(question)).toList();
    } else {
      throw Exception('Failed to load questions');
    }
  }

  /// Prepare the answer options by combining the correct and incorrect answers, then shuffling.
  void prepareOptions(QuizQuestion question) {
    _options = [...question.incorrectAnswers, question.correctAnswer];
    _options.shuffle(Random());
  }

  /// Process the user’s answer selection.
  void _handleAnswer(String answer, QuizQuestion question) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (answer == question.correctAnswer) {
        _score++;
      }
    });
  }

  /// Move to the next question, or navigate to the result screen if finished.
  void _nextQuestion(int totalQuestions) {
    if (_currentQuestionIndex < totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _selectedAnswer = null;
      });
    } else {
      // When finished, pass the score and total questions to the ResultScreen.
      Navigator.pushReplacementNamed(
        context,
        '/result',
        arguments: {'score': _score, 'total': totalQuestions},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuizQuestion>>(
      future: _futureQuestions,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final questions = snapshot.data!;
          // Prepare answer options for the current question if not already set.
          final currentQuestion = questions[_currentQuestionIndex];
          if (!_answered && _options.isEmpty) {
            prepareOptions(currentQuestion);
          }
          return Scaffold(
            appBar: AppBar(
              title: Text('Question ${_currentQuestionIndex + 1}/${questions.length}'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the question. Note: The API returns HTML encoded strings.
                  Text(
                    currentQuestion.question,
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 20),
                  // List of answer options.
                  ..._options.map((option) {
                    Color? optionColor;
                    if (_answered) {
                      if (option == currentQuestion.correctAnswer) {
                        optionColor = Colors.green;
                      } else if (option == _selectedAnswer) {
                        optionColor = Colors.red;
                      }
                    }
                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 10),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: optionColor, // Updated parameter.
                        ),
                        onPressed: () => _handleAnswer(option, currentQuestion),
                        child: Text(option),
                      ),
                    );
                  }).toList(),
                  Spacer(),
                  // Only display the Next button after an answer has been selected.
                  if (_answered)
                    ElevatedButton(
                      onPressed: () {
                        _options.clear();
                        _nextQuestion(questions.length);
                      },
                      child: Text(
                        _currentQuestionIndex < questions.length - 1 ? 'Next Question' : 'See Results',
                      ),
                    ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Trivia Quiz')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        // Show a loading spinner while waiting for data.
        return Scaffold(
          appBar: AppBar(title: Text('Trivia Quiz')),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// ResultScreen: Displays the final score and allows the user to restart the quiz.
class ResultScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Retrieve the score and total number of questions passed via Navigator.
    final Map arguments = ModalRoute.of(context)!.settings.arguments as Map;
    final int score = arguments['score'];
    final int total = arguments['total'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Results'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'You scored $score out of $total!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              child: Text('Restart Quiz'),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/quiz');
              },
            ),
            ElevatedButton(
              child: Text('Back to Home'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
