import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_profile.dart';
import '../models/nutrition_goals.dart';
import '../services/nutrition_provider.dart';

class GoalsSetupScreen extends StatefulWidget {
  const GoalsSetupScreen({super.key});

  @override
  State<GoalsSetupScreen> createState() => _GoalsSetupScreenState();
}

class _GoalsSetupScreenState extends State<GoalsSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // All fields are optional
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _targetWeightController = TextEditingController();
  
  Gender? _gender;
  ActivityLevel? _activityLevel;
  Goal? _goal;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final provider = context.read<NutritionProvider>();
    
    if (provider.goals != null) {
      _caloriesController.text = provider.goals!.calories.toStringAsFixed(0);
      _proteinController.text = provider.goals!.protein.toStringAsFixed(0);
      _carbsController.text = provider.goals!.carbs.toStringAsFixed(0);
      _fatController.text = provider.goals!.fat.toStringAsFixed(0);
    }
    
    if (provider.profile != null) {
      final p = provider.profile!;
      if (p.weight != null) _weightController.text = p.weight!.toStringAsFixed(1);
      if (p.height != null) _heightController.text = p.height!.toStringAsFixed(0);
      if (p.age != null) _ageController.text = p.age!.toString();
      if (p.targetWeight != null) _targetWeightController.text = p.targetWeight!.toStringAsFixed(1);
      _gender = p.gender;
      _activityLevel = p.activityLevel;
      _goal = p.goal;
    }
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) {
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? _parseInt(String text) {
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _calculateFromProfile() {
    final profile = UserProfile(
      weight: _parseDouble(_weightController.text),
      height: _parseDouble(_heightController.text),
      age: _parseInt(_ageController.text),
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: _parseDouble(_targetWeightController.text),
    );

    final suggested = profile.suggestedCalories;
    if (suggested != null) {
      setState(() {
        _caloriesController.text = suggested.toStringAsFixed(0);
        // Auto-calculate macros based on calories
        final goals = NutritionGoals(calories: suggested);
        _proteinController.text = goals.protein.toStringAsFixed(0);
        _carbsController.text = goals.carbs.toStringAsFixed(0);
        _fatController.text = goals.fat.toStringAsFixed(0);
      });
    }
  }

  Future<void> _save() async {
    final provider = context.read<NutritionProvider>();
    
    // Save profile
    final profile = UserProfile(
      weight: _parseDouble(_weightController.text),
      height: _parseDouble(_heightController.text),
      age: _parseInt(_ageController.text),
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: _parseDouble(_targetWeightController.text),
    );
    await provider.setProfile(profile);
    
    // Save goals (use defaults if not specified)
    final calories = _parseDouble(_caloriesController.text) ?? 2000;
    final goals = NutritionGoals(
      calories: calories,
      protein: _parseDouble(_proteinController.text),
      carbs: _parseDouble(_carbsController.text),
      fat: _parseDouble(_fatController.text),
    );
    await provider.setGoals(goals);
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.goals),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Quick calculate section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calculate, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _weightController,
                            label: l10n.weightKg,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _heightController,
                            label: l10n.heightCm,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _ageController,
                            label: l10n.age,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<Gender>(
                            value: _gender,
                            label: l10n.gender,
                            items: Gender.values,
                            itemLabel: (g) => _genderLabel(g),
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<ActivityLevel>(
                      value: _activityLevel,
                      label: l10n.activityLevel,
                      items: ActivityLevel.values,
                      itemLabel: (a) => _activityLabel(a),
                      onChanged: (v) => setState(() => _activityLevel = v),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<Goal>(
                      value: _goal,
                      label: l10n.goal,
                      items: Goal.values,
                      itemLabel: (g) => _goalLabel(g),
                      onChanged: (v) => setState(() => _goal = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _calculateFromProfile,
                        child: Text(l10n.calculateCalories),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Manual goals section
            Text(l10n.orSetManually, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _caloriesController,
              label: l10n.calories,
              keyboardType: TextInputType.number,
              suffix: 'kcal',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _proteinController,
                    label: l10n.protein,
                    keyboardType: TextInputType.number,
                    suffix: 'g',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _carbsController,
                    label: l10n.carbs,
                    keyboardType: TextInputType.number,
                    suffix: 'g',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _fatController,
                    label: l10n.fat,
                    keyboardType: TextInputType.number,
                    suffix: 'g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Target weight
            _buildTextField(
              controller: _targetWeightController,
              label: l10n.targetWeight,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(itemLabel(item)),
      )).toList(),
      onChanged: onChanged,
    );
  }

  String _genderLabel(Gender g) {
    final l10n = AppLocalizations.of(context)!;
    switch (g) {
      case Gender.male: return l10n.genderMale;
      case Gender.female: return l10n.genderFemale;
      case Gender.other: return l10n.genderOther;
    }
  }

  String _activityLabel(ActivityLevel a) {
    final l10n = AppLocalizations.of(context)!;
    switch (a) {
      case ActivityLevel.sedentary: return l10n.activitySedentary;
      case ActivityLevel.light: return l10n.activityLight;
      case ActivityLevel.moderate: return l10n.activityModerate;
      case ActivityLevel.active: return l10n.activityActive;
      case ActivityLevel.veryActive: return l10n.activityVeryActive;
    }
  }

  String _goalLabel(Goal g) {
    final l10n = AppLocalizations.of(context)!;
    switch (g) {
      case Goal.lose: return l10n.goalLose;
      case Goal.maintain: return l10n.goalMaintain;
      case Goal.gain: return l10n.goalGain;
    }
  }
}
