import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FitnessSystemApp());
}

class FitnessSystemApp extends StatefulWidget {
  const FitnessSystemApp({super.key});

  @override
  State<FitnessSystemApp> createState() => _FitnessSystemAppState();
}

class _FitnessSystemAppState extends State<FitnessSystemApp> {
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _settings = AppSettings.fromPrefs(prefs);
    });
  }

  Future<void> _updateSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await settings.saveToPrefs(prefs);
    if (mounted) {
      setState(() {
        _settings = settings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness System',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4EEE5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C6A51),
          brightness: Brightness.light,
        ),
        fontFamily: 'sans-serif',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111315),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B8DFF),
          brightness: Brightness.dark,
        ),
        cardColor: const Color(0xFF1A1D20),
        fontFamily: 'sans-serif',
      ),
      themeMode: _settings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: FitnessDashboardPage(
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}

class FitnessDashboardPage extends StatefulWidget {
  const FitnessDashboardPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSettingsChanged;

  @override
  State<FitnessDashboardPage> createState() => _FitnessDashboardPageState();
}

class _FitnessDashboardPageState extends State<FitnessDashboardPage> {
  final ApiService _api = ApiService();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  bool _isLoginMode = true;
  bool _isAuthenticating = false;
  bool _isLoadingProfile = false;
  bool _isLoadingGoals = true;
  bool _isLoadingPlan = false;
  bool _isLoadingQuest = false;
  bool _isSavingProfile = false;
  int _currentTabIndex = 0;
  late bool _musicEnabled;
  late bool _coachEnabled;
  late bool _timerEnabled;
  late bool _notificationsEnabled;
  late bool _darkModeEnabled;
  late String _language;

  String? _token;
  String? _userEmail;
  String _authMessage =
      'Create an account or log in with your saved credentials.';
  String? _profileMessage;
  String? _selectedGoal;
  String _bmiStatus = 'Waiting';
  WorkoutPlan? _selectedPlan;
  DailyWorkout? _dailyWorkout;
  double? _bmiValue;
  String? _bmiCategory;
  UserProfile? _savedProfile;
  CalorieTargets? _calorieTargets;
  HistorySummary? _historySummary;

  final Map<String, bool> _questProgress = {};
  List<BodyTypePlan> _bodyTypes = const [];

  @override
  void initState() {
    super.initState();
    _applySettings(widget.settings);
    _loadBodyTypes();
  }

  @override
  void didUpdateWidget(covariant FitnessDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _applySettings(widget.settings);
    }
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _applySettings(AppSettings settings) {
    _musicEnabled = settings.musicEnabled;
    _coachEnabled = settings.coachEnabled;
    _timerEnabled = settings.timerEnabled;
    _notificationsEnabled = settings.notificationsEnabled;
    _darkModeEnabled = settings.darkModeEnabled;
    _language = settings.language;
  }

  Future<void> _persistSettings() {
    final settings = AppSettings(
      musicEnabled: _musicEnabled,
      coachEnabled: _coachEnabled,
      timerEnabled: _timerEnabled,
      notificationsEnabled: _notificationsEnabled,
      darkModeEnabled: _darkModeEnabled,
      language: _language,
    );
    return widget.onSettingsChanged(settings);
  }

  String _text(String key) {
    const translations = {
      'Default': {
        'training': 'Training',
        'reports': 'Reports',
        'me': 'Me',
        'account_center': 'Account Center',
        'account_subtitle': 'Create your profile or log in to unlock protected routes.',
        'email': 'Email',
        'password': 'Password',
        'new_password': 'New Password',
        'confirm_password': 'Confirm Password',
        'forgot_password': 'Forgot Password?',
        'reset_password': 'Reset Password',
        'enter_system': 'Enter System',
        'create_account': 'Create Account',
        'weekly_goal': 'Weekly Goal',
        'daily_challenge': 'Daily Challenge',
        'workout_settings': 'Workout Settings',
        'general_settings': 'General Settings',
        'language_options': 'Language Options',
        'rate_us': 'Rate us',
        'share_friends': 'Share with friends',
        'notifications': 'Notifications',
        'dark_mode': 'Dark mode',
        'background_music': 'Background music',
        'voice_coach': 'Voice coach',
        'workout_timer': 'Workout timer',
        'workout': 'Workout',
        'kcal': 'KCAL',
        'time': 'Time',
        'history': 'History',
        'weight': 'Weight',
        'session_status': 'Session Status',
        'load_profile': 'Load Profile',
        'login': 'Login',
        'signup': 'Signup',
        'logout': 'Logout',
        'bmi_calculator': 'BMI Calculator',
        'body_goal_planner': 'Body Goal Planner',
        'system_daily_workout': 'System Daily Workout',
      },
      'English': {},
      'Hindi': {
        'training': 'ट्रेनिंग',
        'reports': 'रिपोर्ट्स',
        'me': 'मैं',
        'account_center': 'अकाउंट सेंटर',
        'account_subtitle': 'अपनी प्रोफ़ाइल बनाएं या सुरक्षित रूट्स के लिए लॉगिन करें।',
        'email': 'ईमेल',
        'password': 'पासवर्ड',
        'new_password': 'नया पासवर्ड',
        'confirm_password': 'पासवर्ड की पुष्टि करें',
        'forgot_password': 'पासवर्ड भूल गए?',
        'reset_password': 'पासवर्ड रीसेट करें',
        'enter_system': 'सिस्टम में जाएं',
        'create_account': 'अकाउंट बनाएं',
        'weekly_goal': 'साप्ताहिक लक्ष्य',
        'daily_challenge': 'दैनिक चुनौती',
        'workout_settings': 'वर्कआउट सेटिंग्स',
        'general_settings': 'सामान्य सेटिंग्स',
        'language_options': 'भाषा विकल्प',
        'rate_us': 'रेट करें',
        'share_friends': 'दोस्तों के साथ साझा करें',
        'notifications': 'सूचनाएं',
        'dark_mode': 'डार्क मोड',
        'background_music': 'बैकग्राउंड म्यूजिक',
        'voice_coach': 'वॉइस कोच',
        'workout_timer': 'वर्कआउट टाइमर',
        'workout': 'वर्कआउट',
        'kcal': 'कैलोरी',
        'time': 'समय',
        'history': 'इतिहास',
        'weight': 'वजन',
        'session_status': 'सेशन स्थिति',
        'load_profile': 'प्रोफ़ाइल लोड करें',
        'login': 'लॉगिन',
        'signup': 'साइन अप',
        'logout': 'लॉगआउट',
        'bmi_calculator': 'बीएमआई कैलकुलेटर',
        'body_goal_planner': 'बॉडी गोल प्लानर',
        'system_daily_workout': 'सिस्टम डेली वर्कआउट',
      },
      'Telugu': {
        'training': 'ట్రైనింగ్',
        'reports': 'రిపోర్ట్స్',
        'me': 'నేను',
        'account_center': 'అకౌంట్ సెంటర్',
        'account_subtitle': 'మీ ప్రొఫైల్ సృష్టించండి లేదా రక్షిత భాగాలకు లాగిన్ అవ్వండి.',
        'email': 'ఇమెయిల్',
        'password': 'పాస్‌వర్డ్',
        'new_password': 'కొత్త పాస్‌వర్డ్',
        'confirm_password': 'పాస్‌వర్డ్ నిర్ధారించండి',
        'forgot_password': 'పాస్‌వర్డ్ మర్చిపోయారా?',
        'reset_password': 'పాస్‌వర్డ్ రీసెట్',
        'enter_system': 'సిస్టమ్‌లోకి వెళ్లండి',
        'create_account': 'అకౌంట్ సృష్టించు',
        'weekly_goal': 'వారపు లక్ష్యం',
        'daily_challenge': 'రోజువారీ ఛాలెంజ్',
        'workout_settings': 'వర్కౌట్ సెట్టింగ్స్',
        'general_settings': 'సాధారణ సెట్టింగ్స్',
        'language_options': 'భాషా ఎంపికలు',
        'rate_us': 'మాకు రేట్ చేయండి',
        'share_friends': 'మిత్రులతో పంచుకోండి',
        'notifications': 'నోటిఫికేషన్స్',
        'dark_mode': 'డార్క్ మోడ్',
        'background_music': 'బ్యాక్‌గ్రౌండ్ మ్యూజిక్',
        'voice_coach': 'వాయిస్ కోచ్',
        'workout_timer': 'వర్కౌట్ టైమర్',
        'workout': 'వర్కౌట్',
        'kcal': 'కేలరీలు',
        'time': 'సమయం',
        'history': 'చరిత్ర',
        'weight': 'బరువు',
        'session_status': 'సెషన్ స్థితి',
        'load_profile': 'ప్రొఫైల్ లోడ్ చేయండి',
        'login': 'లాగిన్',
        'signup': 'సైన్ అప్',
        'logout': 'లాగ్ అవుట్',
        'bmi_calculator': 'బిఎమ్‌ఐ కాలిక్యులేటర్',
        'body_goal_planner': 'బాడీ గోల్ ప్లానర్',
        'system_daily_workout': 'సిస్టమ్ డైలీ వర్కౌట్',
      },
    };

    final languageMap = translations[_language] ?? translations['Default']!;
    final defaultMap = translations['Default']!;
    return languageMap[key] ?? defaultMap[key] ?? key;
  }

  Future<void> _loadBodyTypes() async {
    setState(() => _isLoadingGoals = true);
    try {
      final bodyTypes = await _api.fetchBodyTypes();
      setState(() {
        _bodyTypes = bodyTypes;
      });
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingGoals = false);
      }
    }
  }

  Future<void> _handleAuth() async {
    setState(() => _isAuthenticating = true);
    try {
      if (_isLoginMode) {
        final result = await _api.login(
          _loginEmailController.text.trim(),
          _loginPasswordController.text,
        );
        setState(() {
          _token = result.token;
          _userEmail = result.email;
          _authMessage = 'Login successful';
          _profileMessage = 'Signed in as ${result.email}';
        });
        await _loadDashboard(showSnackOnError: false);
      } else {
        final result = await _api.signup(
          _signupEmailController.text.trim(),
          _signupPasswordController.text,
        );
        setState(() {
          _authMessage = result;
          _isLoginMode = true;
          _loginEmailController.text = _signupEmailController.text.trim();
          _loginPasswordController.text = _signupPasswordController.text;
        });
      }
    } catch (error) {
      setState(() => _authMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    await _loadDashboard();
  }

  Future<void> _loadDashboard({bool showSnackOnError = true}) async {
    if (_token == null) {
      setState(() => _profileMessage = 'Login first to load your profile.');
      return;
    }

    setState(() => _isLoadingProfile = true);
    try {
      final dashboard = await _api.fetchDashboard(_token!);
      setState(() {
        _userEmail = dashboard.email;
        _profileMessage = 'Signed in as ${dashboard.email}';
        _savedProfile = dashboard.profile;
        _calorieTargets = dashboard.profile?.calorieTargets;
        _selectedGoal = dashboard.profile?.bodyGoal ?? _selectedGoal;
        if (dashboard.profile?.weightKg != null) {
          _weightController.text =
              dashboard.profile!.weightKg!.toStringAsFixed(1);
        }
        if (dashboard.profile?.heightCm != null) {
          _heightController.text =
              dashboard.profile!.heightCm!.toStringAsFixed(1);
        }
        _bmiValue = dashboard.profile?.lastBmi;
        _bmiCategory = dashboard.profile?.bmiCategory;
        _bmiStatus = dashboard.profile?.lastBmi == null
            ? 'Waiting'
            : '${dashboard.profile!.bmiCategory} (${dashboard.profile!.lastBmi!.toStringAsFixed(1)})';
        _dailyWorkout = dashboard.dailyWorkout;
        _historySummary = dashboard.historySummary;
        _questProgress
          ..clear()
          ..addAll(dashboard.progress.completedTasks);
      });
    } catch (error) {
      setState(() => _profileMessage = error.toString());
      if (showSnackOnError) {
        _showSnack(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_token == null) {
      setState(() => _authMessage = 'No active session to log out.');
      return;
    }

    try {
      await _api.logout(_token!);
    } catch (_) {
      // We still clear the local session if the token is stale.
    }

    setState(() {
      _token = null;
      _userEmail = null;
      _profileMessage = 'You are not logged in yet.';
      _authMessage = 'Logout successful';
      _savedProfile = null;
      _calorieTargets = null;
      _dailyWorkout = null;
      _historySummary = null;
      _questProgress.clear();
    });
  }

  Future<void> _calculateBmi() async {
    final weight = double.tryParse(_weightController.text);
    final heightCm = double.tryParse(_heightController.text);

    if (weight == null || heightCm == null || weight <= 0 || heightCm <= 0) {
      setState(() {
        _bmiValue = null;
        _bmiCategory = null;
        _bmiStatus = 'Waiting';
      });
      _showSnack('Enter valid weight and height values.');
      return;
    }

    final heightM = heightCm / 100;
    final bmi = weight / (heightM * heightM);
    final category = _bmiCategoryFor(bmi);

    setState(() {
      _bmiValue = bmi;
      _bmiCategory = category;
      _bmiStatus = '$category (${bmi.toStringAsFixed(1)})';
    });

    if (_token != null && _selectedGoal != null && _selectedGoal!.isNotEmpty) {
      await _saveProfileMetrics(showSuccessMessage: true);
    }
  }

  Future<void> _loadWorkoutPlan() async {
    if (_selectedGoal == null || _selectedGoal!.isEmpty) {
      _showSnack('Choose a body type first.');
      return;
    }

    setState(() => _isLoadingPlan = true);
    try {
      final plan = await _api.fetchWorkoutPlan(_selectedGoal!);
      setState(() => _selectedPlan = plan);
      if (_token != null &&
          _weightController.text.trim().isNotEmpty &&
          _heightController.text.trim().isNotEmpty) {
        await _saveProfileMetrics();
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    }
  }

  Future<void> _loadDailyWorkout() async {
    setState(() => _isLoadingQuest = true);
    try {
      if (_token != null) {
        await _loadDashboard(showSnackOnError: false);
      } else {
        final dailyWorkout = await _api.fetchDailyWorkout();
        setState(() {
          _dailyWorkout = dailyWorkout;
          _questProgress
            ..clear()
            ..addEntries(
              dailyWorkout.tasks.map((task) => MapEntry(task.name, false)),
            );
        });
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuest = false);
      }
    }
  }

  Future<void> _resetQuestProgress() async {
    if (_token != null && _dailyWorkout != null) {
      for (final task in _dailyWorkout!.tasks) {
        await _api.updateDailyProgress(_token!, task.name, false);
      }
      await _loadDashboard(showSnackOnError: false);
      return;
    }

    setState(() {
      for (final task in _questProgress.keys) {
        _questProgress[task] = false;
      }
    });
  }

  Future<void> _toggleQuest(String taskName, bool value) async {
    if (_token == null) {
      setState(() => _questProgress[taskName] = value);
      return;
    }

    try {
      final progress = await _api.updateDailyProgress(_token!, taskName, value);
      setState(() {
        _questProgress
          ..clear()
          ..addAll(progress.completedTasks);
      });
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _saveProfileMetrics({bool showSuccessMessage = false}) async {
    if (_token == null) {
      _showSnack('Login first to save BMI, goal, and calories.');
      return;
    }

    if (_selectedGoal == null || _selectedGoal!.isEmpty) {
      _showSnack('Select a body goal before saving your profile.');
      return;
    }

    final weight = double.tryParse(_weightController.text);
    final heightCm = double.tryParse(_heightController.text);

    if (weight == null || heightCm == null || weight <= 0 || heightCm <= 0) {
      _showSnack('Enter valid height and weight before saving.');
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final profile = await _api.updateProfile(
        _token!,
        heightCm: heightCm,
        weightKg: weight,
        bodyGoal: _selectedGoal!,
      );
      setState(() {
        _savedProfile = profile;
        _calorieTargets = profile.calorieTargets;
        _bmiValue = profile.lastBmi;
        _bmiCategory = profile.bmiCategory;
        _bmiStatus = profile.lastBmi == null
            ? 'Waiting'
            : '${profile.bmiCategory} (${profile.lastBmi!.toStringAsFixed(1)})';
      });
      if (showSuccessMessage) {
        _showSnack('Profile, BMI, and calorie targets saved.');
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  int get _completedTasks =>
      _questProgress.values.where((value) => value).length;

  int get _totalTasks => _dailyWorkout?.tasks.length ?? 4;

  double get _questPercent =>
      _totalTasks == 0 ? 0 : _completedTasks / _totalTasks;

  String _bmiCategoryFor(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openWorkoutSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('workout_settings'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _musicEnabled,
                    title: Text(_text('background_music')),
                    subtitle: const Text('Keep music active during workouts'),
                    onChanged: (value) {
                      setModalState(() => _musicEnabled = value);
                      setState(() => _musicEnabled = value);
                      _persistSettings();
                    },
                  ),
                  SwitchListTile(
                    value: _coachEnabled,
                    title: Text(_text('voice_coach')),
                    subtitle: const Text('Read exercise guidance aloud'),
                    onChanged: (value) {
                      setModalState(() => _coachEnabled = value);
                      setState(() => _coachEnabled = value);
                      _persistSettings();
                    },
                  ),
                  SwitchListTile(
                    value: _timerEnabled,
                    title: Text(_text('workout_timer')),
                    subtitle: const Text('Show active timer during sessions'),
                    onChanged: (value) {
                      setModalState(() => _timerEnabled = value);
                      setState(() => _timerEnabled = value);
                      _persistSettings();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openGeneralSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('general_settings'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _notificationsEnabled,
                    title: Text(_text('notifications')),
                    subtitle: const Text('Workout reminders and streak prompts'),
                    onChanged: (value) {
                      setModalState(() => _notificationsEnabled = value);
                      setState(() => _notificationsEnabled = value);
                      _persistSettings();
                    },
                  ),
                  SwitchListTile(
                    value: _darkModeEnabled,
                    title: Text(_text('dark_mode')),
                    subtitle: const Text('Preview theme preference for future use'),
                    onChanged: (value) {
                      setModalState(() => _darkModeEnabled = value);
                      setState(() => _darkModeEnabled = value);
                      _persistSettings();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_text('language_options')),
                    subtitle: Text(_language),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLanguageOptions() async {
    const languages = ['Default', 'English', 'Hindi', 'Telugu'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_text('language_options')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages
                .map(
                  (language) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _language == language
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _language == language
                          ? const Color(0xFF356DFF)
                          : const Color(0xFF9B9B9B),
                    ),
                    title: Text(language),
                    onTap: () {
                      Navigator.of(context).pop(language);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _language = selected);
      await _persistSettings();
      _showSnack('Language set to $selected');
    }
  }

  Future<void> _openRateUs() async {
    double rating = 5;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate us'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How would you rate your experience so far?'),
                  const SizedBox(height: 16),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: rating.toStringAsFixed(0),
                    onChanged: (value) {
                      setDialogState(() => rating = value);
                    },
                  ),
                  Text(
                    '${rating.toStringAsFixed(0)} / 5',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showSnack('Thanks for rating the app ${rating.toStringAsFixed(0)} stars!');
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareWithFriends() async {
    const inviteMessage =
        'Join me on Fitness System and start your 30-day workout streak!';
    await Clipboard.setData(const ClipboardData(text: inviteMessage));
    _showSnack('Invite message copied. You can paste it anywhere and share.');
  }

  Future<void> _openForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _loginEmailController.text.trim(),
    );
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final email = emailController.text.trim();
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                _showSnack('Please fill all reset password fields.');
                return;
              }

              if (newPassword != confirmPassword) {
                _showSnack('New password and confirmation do not match.');
                return;
              }

              setDialogState(() => submitting = true);
              try {
                final message = await _api.forgotPassword(email, newPassword);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _showSnack(message);
                setState(() {
                  _isLoginMode = true;
                  _loginEmailController.text = email;
                  _loginPasswordController.clear();
                });
              } catch (error) {
                _showSnack(error.toString());
              } finally {
                if (context.mounted) {
                  setDialogState(() => submitting = false);
                }
              }
            }

            return AlertDialog(
              title: Text(_text('reset_password')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Field(
                      label: _text('email'),
                      controller: emailController,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: _text('new_password'),
                      controller: newPasswordController,
                      obscure: true,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: _text('confirm_password'),
                      controller: confirmPasswordController,
                      obscure: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: Text(
                    submitting ? 'Please wait...' : _text('reset_password'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildTrainingTab(),
                _buildReportsTab(),
                _buildMeTab(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: _text('training'),
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: _text('reports'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: _text('me'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingTab() {
    final dailyWorkout = _dailyWorkout;
    final completedDays = _historySummary?.completedDays ?? 0;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)
        ?? const Color(0xFF757575);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitness System',
            style: TextStyle(fontSize: 20, color: mutedColor),
          ),
          const SizedBox(height: 6),
          Text(
            '30 Days Fitness',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _buildWeeklyGoalCard(),
          const SizedBox(height: 24),
          Text(
            _text('daily_challenge'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF1F7BFF), Color(0xFF0B57DB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedGoal == null
                      ? 'Stay Consistent'
                      : _selectedGoal!.replaceAll('weightloss', 'weight loss'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Day ${completedDays + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$completedDays/30 Days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (completedDays.clamp(0, 30)) / 30,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoadingQuest
                        ? null
                        : () {
                            _loadDailyWorkout();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'START',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _buildCompactStatsRow(),
          const SizedBox(height: 22),
          _buildGoalPlannerCard(),
          const SizedBox(height: 22),
          _buildBmiCard(),
          const SizedBox(height: 22),
          if (dailyWorkout != null) _buildQuestCard(),
          if (dailyWorkout == null)
            _buildMobilePlaceholder(
              title: 'Daily workout not loaded yet',
              subtitle: 'Tap START to load your challenge and record today\'s streak.',
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoalCard() {
    final recentDays = _historySummary?.calendarDays.skip(
          ((_historySummary?.calendarDays.length ?? 7) - 7).clamp(0, 999),
        ).toList() ??
        _fallbackWeekDays();
    final weeklyCompleted = recentDays.where((day) => day.completed).length;
    final surfaceColor = Theme.of(context).cardColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('weekly_goal'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$weeklyCompleted/${_historySummary?.weeklyGoal ?? 3} workouts',
                style: const TextStyle(
                  color: Color(0xFF356DFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: recentDays
                .map(
                  (day) => _CalendarBubble(
                    label: '${day.day}',
                    active: day.isToday,
                    complete: day.completed,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_notificationsEnabled)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFDFE8FF),
                    child: Icon(Icons.favorite, color: Color(0xFF356DFF)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Your fitness goals are calling - time to answer with a workout!',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications_off_outlined, color: Color(0xFF7A7A7A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications are off. Turn them on in settings to get workout reminders.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Streak',
            value: '${_historySummary?.currentStreak ?? 0} day',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Best',
            value: '${_historySummary?.bestStreak ?? 0} day',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Goal',
            value: _selectedGoal ?? 'None',
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCalendarCard() {
    final history = _historySummary;
    final days = history?.calendarDays ?? _fallbackMonthDays();
    final surfaceColor = Theme.of(context).cardColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '30-Day Calendar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: days
                .map(
                  (day) => SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Text(
                          day.weekday.substring(0, 1),
                          style: const TextStyle(
                            color: Color(0xFF9B9B9B),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _CalendarBubble(
                          label: '${day.day}',
                          active: day.isToday,
                          complete: day.completed,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFF8A00)),
              const SizedBox(width: 8),
              Text(
                '${history?.currentStreak ?? 0} Day streak',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Personal best: ${history?.bestStreak ?? 0} Day',
                style: const TextStyle(
                  color: Color(0xFF8C8C8C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    final weight = _savedProfile?.weightKg;
    final surfaceColor = Theme.of(context).cardColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weight',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  _currentTabIndex = 0;
                  setState(() {});
                },
                child: const Text('+ Log'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current',
                  style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  weight == null ? '--' : '${weight.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                  ),
                  child: CustomPaint(
                    painter: _WeightGridPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF2F5FF),
              child: Icon(icon, color: const Color(0xFF356DFF)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePlaceholder({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF7A7A7A), height: 1.45),
          ),
        ],
      ),
    );
  }

  List<CalendarDay> _fallbackWeekDays() {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final current = today.subtract(Duration(days: 6 - index));
      return CalendarDay(
        date: current.toIso8601String().split('T').first,
        day: current.day,
        weekday: _weekdayShort(current.weekday),
        completed: false,
        isToday: index == 6,
      );
    });
  }

  List<CalendarDay> _fallbackMonthDays() {
    final today = DateTime.now();
    return List.generate(30, (index) {
      final current = today.subtract(Duration(days: 29 - index));
      return CalendarDay(
        date: current.toIso8601String().split('T').first,
        day: current.day,
        weekday: _weekdayShort(current.weekday),
        completed: false,
        isToday: index == 29,
      );
    });
  }

  String _weekdayShort(int weekday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('reports'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ReportMetric(
                    label: _text('workout').toUpperCase(),
                    value: '${_historySummary?.completedDays ?? 0}',
                  ),
                ),
                Expanded(
                  child: _ReportMetric(
                    label: _text('kcal').toUpperCase(),
                    value: _calorieTargets == null
                        ? '0.0'
                        : '${_calorieTargets!.goalCalories}',
                  ),
                ),
                Expanded(
                  child: _ReportMetric(
                    label: _text('time').toUpperCase(),
                    value: '${_completedTasks * 10}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            _text('history'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _buildHistoryCalendarCard(),
          const SizedBox(height: 24),
          _buildWeightCard(),
        ],
      ),
    );
  }

  Widget _buildMeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('me'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF3A7BFF), Color(0xFF634DFF)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backup & Restore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userEmail ?? 'Sign in and synchronize your data',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.cloud_sync, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildSettingsTile(
            icon: Icons.music_note_outlined,
            title: 'Workout Settings',
            subtitle: 'Music & coach & timer, etc.',
            onTap: _openWorkoutSettings,
          ),
          _buildSettingsTile(
            icon: Icons.settings_outlined,
            title: 'General Settings',
            subtitle: 'Preferences and app behavior.',
            onTap: _openGeneralSettings,
          ),
          _buildSettingsTile(
            icon: Icons.language_outlined,
            title: 'Language Options',
            subtitle: _language,
            onTap: _openLanguageOptions,
          ),
          _buildSettingsTile(
            icon: Icons.star_outline,
            title: 'Rate us',
            subtitle: 'Share your feedback.',
            onTap: _openRateUs,
          ),
          _buildSettingsTile(
            icon: Icons.share_outlined,
            title: 'Share with friends',
            subtitle: 'Invite someone to train with you.',
            onTap: _shareWithFriends,
          ),
          const SizedBox(height: 18),
          _buildAccountCard(),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopBar() {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'FITNESS SYSTEM',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C6A51),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Daily discipline with a level-up loop.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F241F),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _NavChip(label: 'Account'),
              _NavChip(label: 'Metrics'),
              _NavChip(label: 'Plans'),
              _NavChip(label: 'Quests'),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 900;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            SizedBox(
              width: singleColumn ? constraints.maxWidth : constraints.maxWidth * 0.62,
              child: _GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1F2C6A51),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'System Interface',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F5139),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Build a routine that feels like a questline, not a chore list.',
                      style: TextStyle(
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1E1B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sign in, calculate your BMI, choose a body goal, and load a daily quest board inspired by Solo Leveling.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF617063),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ActionButton(
                          label: 'Choose Your Goal',
                          filled: true,
                          onPressed: () {},
                        ),
                        _ActionButton(
                          label: 'Open Quest Board',
                          filled: false,
                          onPressed: () {
                            _loadDailyWorkout();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: singleColumn ? constraints.maxWidth : constraints.maxWidth * 0.34,
              child: _GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1FC9752B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'System Online',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A4C14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Available Goals',
                            value: '${_bodyTypes.length}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            label: 'Quest Tasks',
                            value: '$_totalTasks',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            label: 'Session',
                            value: _userEmail ?? 'Guest',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Secure login with token session'),
                    const SizedBox(height: 8),
                    const Text('Goal-based workout planning'),
                    const SizedBox(height: 8),
                    const Text('Progress-based quest completion'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _SnapshotCard(
            label: 'Selected Goal',
            value: _selectedGoal ?? 'Not selected',
            note: 'Pick a body goal to personalize the board.',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SnapshotCard(
            label: 'BMI Status',
            value: _bmiStatus,
            note: 'Your BMI result updates after calculation.',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SnapshotCard(
            label: 'Quest Progress',
            value: '$_completedTasks / $_totalTasks complete',
            note: 'Track daily task completion through the quest board.',
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: _text('account_center'),
            subtitle: _text('account_subtitle'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ModeChip(
                label: _text('login'),
                selected: _isLoginMode,
                onTap: () => setState(() => _isLoginMode = true),
              ),
              const SizedBox(width: 10),
              _ModeChip(
                label: _text('signup'),
                selected: !_isLoginMode,
                onTap: () => setState(() => _isLoginMode = false),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Field(
            label: _text('email'),
            controller:
                _isLoginMode ? _loginEmailController : _signupEmailController,
          ),
          const SizedBox(height: 12),
          _Field(
            label: _text('password'),
            controller: _isLoginMode
                ? _loginPasswordController
                : _signupPasswordController,
            obscure: true,
          ),
          if (_isLoginMode) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPasswordDialog,
                child: Text(_text('forgot_password')),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isAuthenticating
                ? null
                : () {
                    _handleAuth();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C6A51),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              _isLoginMode ? _text('enter_system') : _text('create_account'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x1A1B1E1B)),
            ),
            child: Text(_authMessage),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: _text('session_status'),
            subtitle: 'Track the active account and refresh the profile route.',
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x1A1B1E1B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_profileMessage ?? 'You are not logged in yet.'),
                if (_savedProfile != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Saved goal: ${_savedProfile!.bodyGoal ?? 'Not set'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Weight: ${_savedProfile!.weightKg?.toStringAsFixed(1) ?? '--'} kg',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Height: ${_savedProfile!.heightCm?.toStringAsFixed(1) ?? '--'} cm',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isLoadingProfile
                      ? null
                      : () {
                          _loadProfile();
                        },
                  child: Text(_text('load_profile')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _logout();
                  },
                  child: Text(_text('logout')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBmiCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: _text('bmi_calculator'),
            subtitle: 'Measure your current status and set better expectations.',
          ),
          _Field(label: 'Weight (kg)', controller: _weightController),
          const SizedBox(height: 12),
          _Field(label: 'Height (cm)', controller: _heightController),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              _calculateBmi();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C6A51),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Calculate BMI'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isSavingProfile
                ? null
                : () {
                    _saveProfileMetrics();
                  },
            child: Text(_isSavingProfile ? 'Saving...' : 'Save BMI + Goal'),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x1A1B1E1B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_bmiValue == null)
                  const Text('BMI result will appear here.')
                else ...[
                  Text(
                    'BMI: ${_bmiValue!.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Category: $_bmiCategory'),
                ],
                if (_calorieTargets != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Goal Calories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _calorieRow(
                    'Maintenance',
                    '${_calorieTargets!.maintenanceCalories} kcal',
                  ),
                  _calorieRow(
                    '${_calorieTargets!.goal.toUpperCase()} target',
                    '${_calorieTargets!.goalCalories} kcal',
                  ),
                  _calorieRow(
                    'Protein',
                    '${_calorieTargets!.proteinGrams} g',
                  ),
                  _calorieRow(
                    'Carbs',
                    '${_calorieTargets!.carbsGrams} g',
                  ),
                  _calorieRow(
                    'Fats',
                    '${_calorieTargets!.fatsGrams} g',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPlannerCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: _text('body_goal_planner'),
            subtitle: 'Choose the path that matches your current goal.',
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedGoal,
                  items: _bodyTypes
                      .map(
                        (goal) => DropdownMenuItem<String>(
                          value: goal.key,
                          child: Text(goal.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGoal = value),
                  decoration: _inputDecoration('Choose a goal'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isLoadingPlan
                    ? null
                    : () {
                        _loadWorkoutPlan();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C6A51),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                ),
                child: const Text('Get Plan'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingGoals)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _bodyTypes
                  .map(
                    (goal) => _GoalCard(
                      goal: goal,
                      selected: _selectedGoal == goal.key,
                      onTap: () => setState(() => _selectedGoal = goal.key),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x1A1B1E1B)),
            ),
            child: _selectedPlan == null
                ? const Text('Your selected plan will appear here.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPlan!.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1F2C6A51),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _selectedPlan!.repRange,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F5139),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_selectedPlan!.focus),
                      const SizedBox(height: 14),
                      ..._selectedPlan!.exercises.map(
                        (exercise) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF2C6A51),
                              ),
                              const SizedBox(width: 10),
                              Text(exercise),
                            ],
                          ),
                        ),
                      ),
                      if (_calorieTargets != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x142C6A51),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Recommended calories for ${_calorieTargets!.goal}: ${_calorieTargets!.goalCalories} kcal/day',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard() {
    final dailyWorkout = _dailyWorkout;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: _text('system_daily_workout'),
            subtitle: 'Load your quest board, complete tasks, and keep your streak alive.',
          ),
          Row(
            children: [
              FilledButton(
                onPressed: _isLoadingQuest
                    ? null
                    : () {
                        _loadDailyWorkout();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C6A51),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                ),
                child: const Text('Load Daily Quest'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  _resetQuestProgress();
                },
                child: const Text('Reset Progress'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Completion',
                  value: '${(_questPercent * 100).round()}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Completed Tasks',
                  value: '$_completedTasks',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _MiniStat(label: 'Current Streak', value: '1 day'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x1A1B1E1B)),
            ),
            child: dailyWorkout == null
                ? const Text('Your daily quest board will appear here.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dailyWorkout.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F5139),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Theme: ${dailyWorkout.theme}'),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1F2C6A51),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${(_questPercent * 100).round()}% complete',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F5139),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _questPercent,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: const Color(0x141B1E1B),
                        color: const Color(0xFFC9752B),
                      ),
                      const SizedBox(height: 18),
                      ...dailyWorkout.tasks.map(
                        (task) => _QuestTile(
                          task: task,
                          checked: _questProgress[task.name] ?? false,
                          onChanged: (value) {
                            _toggleQuest(task.name, value);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(dailyWorkout.message),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0x211B1E1B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0x211B1E1B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2C6A51)),
      ),
    );
  }

  Widget _calorieRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF617063)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.musicEnabled = true,
    this.coachEnabled = true,
    this.timerEnabled = true,
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.language = 'Default',
  });

  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    return AppSettings(
      musicEnabled: prefs.getBool('musicEnabled') ?? true,
      coachEnabled: prefs.getBool('coachEnabled') ?? true,
      timerEnabled: prefs.getBool('timerEnabled') ?? true,
      notificationsEnabled: prefs.getBool('notificationsEnabled') ?? true,
      darkModeEnabled: prefs.getBool('darkModeEnabled') ?? false,
      language: prefs.getString('language') ?? 'Default',
    );
  }

  final bool musicEnabled;
  final bool coachEnabled;
  final bool timerEnabled;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final String language;

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setBool('musicEnabled', musicEnabled);
    await prefs.setBool('coachEnabled', coachEnabled);
    await prefs.setBool('timerEnabled', timerEnabled);
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
    await prefs.setBool('darkModeEnabled', darkModeEnabled);
    await prefs.setString('language', language);
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.musicEnabled == musicEnabled &&
        other.coachEnabled == coachEnabled &&
        other.timerEnabled == timerEnabled &&
        other.notificationsEnabled == notificationsEnabled &&
        other.darkModeEnabled == darkModeEnabled &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(
        musicEnabled,
        coachEnabled,
        timerEnabled,
        notificationsEnabled,
        darkModeEnabled,
        language,
      );
}

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:5000';

  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(response);
    return AuthResult(token: data['token'] as String, email: data['user']['email'] as String);
  }

  Future<String> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(response);
    return data['message'] as String;
  }

  Future<String> forgotPassword(String email, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'new_password': newPassword,
      }),
    );
    final data = _decode(response);
    return data['message'] as String;
  }

  Future<ProfileResponse> profile(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(response);
    return ProfileResponse.fromJson(data);
  }

  Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/logout'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _decode(response);
  }

  Future<List<BodyTypePlan>> fetchBodyTypes() async {
    final response = await http.get(Uri.parse('$_baseUrl/body-types'));
    final data = _decode(response);
    final bodyTypes = data['body_types'] as List<dynamic>;
    return bodyTypes
        .map((item) => BodyTypePlan.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutPlan> fetchWorkoutPlan(String bodyType) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/workout?body_type=$bodyType'),
    );
    final data = _decode(response);
    return WorkoutPlan.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<DailyWorkout> fetchDailyWorkout() async {
    final response = await http.get(Uri.parse('$_baseUrl/daily-workout'));
    final data = _decode(response);
    return DailyWorkout.fromJson(data['daily_workout'] as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile(
    String token, {
    required double heightCm,
    required double weightKg,
    required String bodyGoal,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/profile/update'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'body_goal': bodyGoal,
      }),
    );
    final data = _decode(response);
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<ProgressData> updateDailyProgress(
    String token,
    String taskName,
    bool completed,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/daily-workout/progress'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'task_name': taskName,
        'completed': completed,
      }),
    );
    final data = _decode(response);
    return ProgressData.fromJson(data['progress'] as Map<String, dynamic>);
  }

  Future<DashboardData> fetchDashboard(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(response);
    return DashboardData.fromJson(data);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Request failed');
    }
    return data;
  }
}

class AuthResult {
  const AuthResult({required this.token, required this.email});

  final String token;
  final String email;
}

class ProfileResponse {
  const ProfileResponse({required this.email, required this.profile});

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      email: json['user']['email'] as String,
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  final String email;
  final UserProfile profile;
}

class BodyTypePlan {
  const BodyTypePlan({
    required this.key,
    required this.title,
    required this.focus,
  });

  factory BodyTypePlan.fromJson(Map<String, dynamic> json) {
    return BodyTypePlan(
      key: json['key'] as String,
      title: json['title'] as String,
      focus: json['focus'] as String,
    );
  }

  final String key;
  final String title;
  final String focus;
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.title,
    required this.focus,
    required this.repRange,
    required this.exercises,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      title: json['title'] as String,
      focus: json['focus'] as String,
      repRange: json['rep_range'] as String,
      exercises: (json['exercises'] as List<dynamic>).cast<String>(),
    );
  }

  final String title;
  final String focus;
  final String repRange;
  final List<String> exercises;
}

class DailyWorkout {
  const DailyWorkout({
    required this.title,
    required this.theme,
    required this.message,
    required this.tasks,
  });

  factory DailyWorkout.fromJson(Map<String, dynamic> json) {
    return DailyWorkout(
      title: json['title'] as String,
      theme: json['theme'] as String,
      message: json['message'] as String,
      tasks: (json['tasks'] as List<dynamic>)
          .map((task) => QuestTask.fromJson(task as Map<String, dynamic>))
          .toList(),
    );
  }

  final String title;
  final String theme;
  final String message;
  final List<QuestTask> tasks;
}

class QuestTask {
  const QuestTask({
    required this.name,
    required this.target,
    this.completed = false,
  });

  factory QuestTask.fromJson(Map<String, dynamic> json) {
    return QuestTask(
      name: json['name'] as String,
      target: json['target'] as String,
      completed: json['completed'] as bool? ?? false,
    );
  }

  final String name;
  final String target;
  final bool completed;
}

class CalorieTargets {
  const CalorieTargets({
    required this.maintenanceCalories,
    required this.goalCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    required this.goal,
  });

  factory CalorieTargets.fromJson(Map<String, dynamic> json) {
    return CalorieTargets(
      maintenanceCalories: json['maintenance_calories'] as int,
      goalCalories: json['goal_calories'] as int,
      proteinGrams: json['protein_grams'] as int,
      carbsGrams: json['carbs_grams'] as int,
      fatsGrams: json['fats_grams'] as int,
      goal: json['goal'] as String,
    );
  }

  final int maintenanceCalories;
  final int goalCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;
  final String goal;
}

class UserProfile {
  const UserProfile({
    this.heightCm,
    this.weightKg,
    this.bodyGoal,
    this.lastBmi,
    this.bmiCategory,
    this.calorieTargets,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      bodyGoal: json['body_goal'] as String?,
      lastBmi: (json['last_bmi'] as num?)?.toDouble(),
      bmiCategory: json['bmi_category'] as String?,
      calorieTargets: json['calorie_targets'] == null
          ? null
          : CalorieTargets.fromJson(
              json['calorie_targets'] as Map<String, dynamic>,
            ),
    );
  }

  final double? heightCm;
  final double? weightKg;
  final String? bodyGoal;
  final double? lastBmi;
  final String? bmiCategory;
  final CalorieTargets? calorieTargets;
}

class ProgressData {
  const ProgressData({
    required this.date,
    required this.tasks,
    required this.completedCount,
    required this.totalCount,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    final tasks = (json['tasks'] as List<dynamic>)
        .map((task) => QuestTask.fromJson(task as Map<String, dynamic>))
        .toList();
    return ProgressData(
      date: json['date'] as String,
      tasks: tasks,
      completedCount: json['completed_count'] as int,
      totalCount: json['total_count'] as int,
    );
  }

  final String date;
  final List<QuestTask> tasks;
  final int completedCount;
  final int totalCount;

  Map<String, bool> get completedTasks => {
        for (final task in tasks) task.name: task.completed,
      };
}

class DashboardData {
  const DashboardData({
    required this.email,
    this.profile,
    required this.dailyWorkout,
    required this.progress,
    required this.historySummary,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final progress = ProgressData.fromJson(
      json['daily_progress'] as Map<String, dynamic>,
    );
    final dailyMeta = json['daily_workout'] as Map<String, dynamic>;
    return DashboardData(
      email: json['user']['email'] as String,
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      dailyWorkout: DailyWorkout(
        title: dailyMeta['title'] as String,
        theme: dailyMeta['theme'] as String,
        message: dailyMeta['message'] as String,
        tasks: progress.tasks,
      ),
      progress: progress,
      historySummary: HistorySummary.fromJson(
        json['history_summary'] as Map<String, dynamic>,
      ),
    );
  }

  final String email;
  final UserProfile? profile;
  final DailyWorkout dailyWorkout;
  final ProgressData progress;
  final HistorySummary historySummary;
}

class HistorySummary {
  const HistorySummary({
    required this.calendarDays,
    required this.completedDays,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyGoal,
  });

  factory HistorySummary.fromJson(Map<String, dynamic> json) {
    return HistorySummary(
      calendarDays: (json['calendar_days'] as List<dynamic>)
          .map((day) => CalendarDay.fromJson(day as Map<String, dynamic>))
          .toList(),
      completedDays: json['completed_days'] as int,
      currentStreak: json['current_streak'] as int,
      bestStreak: json['best_streak'] as int,
      weeklyGoal: json['weekly_goal'] as int,
    );
  }

  final List<CalendarDay> calendarDays;
  final int completedDays;
  final int currentStreak;
  final int bestStreak;
  final int weeklyGoal;
}

class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.day,
    required this.weekday,
    required this.completed,
    required this.isToday,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: json['date'] as String,
      day: json['day'] as int,
      weekday: json['weekday'] as String,
      completed: json['completed'] as bool,
      isToday: json['is_today'] as bool,
    );
  }

  final String date;
  final int day;
  final String weekday;
  final bool completed;
  final bool isToday;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1A1B1E1B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2A342B),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B1E1B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF617063),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _obscureText = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF617063),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.92),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0x211B1E1B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0x211B1E1B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF2C6A51)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final BodyTypePlan goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 250,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0x662C6A51) : const Color(0x141B1E1B),
          ),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0x1F2C6A51), Color(0x14FFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: Colors.white.withValues(alpha: 0.62),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal.focus,
              style: const TextStyle(height: 1.45, color: Color(0xFF617063)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.task,
    required this.checked,
    required this.onChanged,
  });

  final QuestTask task;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.target,
                  style: const TextStyle(color: Color(0xFF617063)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: checked ? const Color(0xFFDBF0E4) : Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              checked ? 'Done' : 'Pending',
              style: TextStyle(
                color: checked ? const Color(0xFF1F7A4C) : const Color(0xFF7A7A7A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x121B1E1B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              color: Color(0xFF617063),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1E1B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBubble extends StatelessWidget {
  const _CalendarBubble({
    required this.label,
    required this.active,
    required this.complete,
  });

  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? const Color(0xFF111111)
            : complete
                ? const Color(0xFFDBF0E4)
                : const Color(0xFFF1F1F1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: active
              ? Colors.white
              : complete
                  ? const Color(0xFF1F7A4C)
                  : const Color(0xFF333333),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA0A0A0),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WeightGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAEAEA)
      ..strokeWidth = 1;

    const rows = 5;
    const cols = 6;
    for (int row = 1; row < rows; row++) {
      final y = size.height * row / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int col = 1; col < cols; col++) {
      final x = size.width * col / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.8,
              color: Color(0xFF617063),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1E1B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(color: Color(0xFF617063)),
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF617063),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x142C6A51),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF1B1E1B) : const Color(0xFF617063),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C6A51),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          );

    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
  }
}
