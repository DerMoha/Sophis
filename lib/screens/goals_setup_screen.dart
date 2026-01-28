import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';
import '../models/nutrition_goals.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/unit_converter.dart';
import '../widgets/organic_components.dart';

class GoalsSetupScreen extends StatefulWidget {
  const GoalsSetupScreen({super.key});

  @override
  State<GoalsSetupScreen> createState() => _GoalsSetupScreenState();
}

class _GoalsSetupScreenState extends State<GoalsSetupScreen> {
  final _formKey = GlobalKey<FormState>();

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
    final unitSystem = context.read<SettingsProvider>().unitSystem;

    if (provider.goals != null) {
      _caloriesController.text = provider.goals!.calories.toStringAsFixed(0);
      _proteinController.text = provider.goals!.protein.toStringAsFixed(0);
      _carbsController.text = provider.goals!.carbs.toStringAsFixed(0);
      _fatController.text = provider.goals!.fat.toStringAsFixed(0);
    }

    if (provider.profile != null) {
      final p = provider.profile!;
      if (p.weight != null) {
        final displayWeight = UnitConverter.displayWeight(p.weight!, unitSystem);
        _weightController.text = displayWeight.toStringAsFixed(1);
      }
      if (p.height != null) {
        final displayHeight = UnitConverter.displayHeight(p.height!, unitSystem);
        _heightController.text = displayHeight.toStringAsFixed(0);
      }
      if (p.age != null) _ageController.text = p.age!.toString();
      if (p.targetWeight != null) {
        final displayTargetWeight = UnitConverter.displayWeight(p.targetWeight!, unitSystem);
        _targetWeightController.text = displayTargetWeight.toStringAsFixed(1);
      }
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
    final unitSystem = context.read<SettingsProvider>().unitSystem;

    // Convert input values to metric for calculation
    final weightInput = _parseDouble(_weightController.text);
    final heightInput = _parseDouble(_heightController.text);
    final targetWeightInput = _parseDouble(_targetWeightController.text);

    final profile = UserProfile(
      weight: weightInput != null ? UnitConverter.inputToKg(weightInput, unitSystem) : null,
      height: heightInput != null ? UnitConverter.inputToCm(heightInput, unitSystem) : null,
      age: _parseInt(_ageController.text),
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: targetWeightInput != null ? UnitConverter.inputToKg(targetWeightInput, unitSystem) : null,
    );

    final suggested = profile.suggestedCalories;
    if (suggested != null) {
      setState(() {
        _caloriesController.text = suggested.toStringAsFixed(0);
        final goals = NutritionGoals(calories: suggested);
        _proteinController.text = goals.protein.toStringAsFixed(0);
        _carbsController.text = goals.carbs.toStringAsFixed(0);
        _fatController.text = goals.fat.toStringAsFixed(0);
      });
    }
  }

  Future<void> _save() async {
    final provider = context.read<NutritionProvider>();
    final unitSystem = context.read<SettingsProvider>().unitSystem;

    // Convert input values to metric for storage
    final weightInput = _parseDouble(_weightController.text);
    final heightInput = _parseDouble(_heightController.text);
    final targetWeightInput = _parseDouble(_targetWeightController.text);

    final profile = UserProfile(
      weight: weightInput != null ? UnitConverter.inputToKg(weightInput, unitSystem) : null,
      height: heightInput != null ? UnitConverter.inputToCm(heightInput, unitSystem) : null,
      age: _parseInt(_ageController.text),
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: targetWeightInput != null ? UnitConverter.inputToKg(targetWeightInput, unitSystem) : null,
    );
    await provider.setProfile(profile);

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
    final unitSystem = context.watch<SettingsProvider>().unitSystem;
    final weightLabel = unitSystem == UnitSystem.imperial ? l10n.weightLb : l10n.weightKg;
    final heightLabel = unitSystem == UnitSystem.imperial ? l10n.heightIn : l10n.heightCm;
    final targetWeightLabel = unitSystem == UnitSystem.imperial ? l10n.targetWeightLb : l10n.targetWeight;
    final weightUnit = UnitConverter.weightUnit(unitSystem);
    final heightUnit = UnitConverter.heightUnit(unitSystem);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                l10n.goals,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _save,
                  child: Text(
                    l10n.save,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calculator Section
                      FadeInSlide(
                        index: 0,
                        child: OrganicCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.primary
                                              .withValues(alpha: 0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.calculate_outlined,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.calculate,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        Text(
                                          l10n.basedOnProfile,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Weight & Height
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _weightController,
                                      label: weightLabel,
                                      icon: Icons.monitor_weight_outlined,
                                      suffix: weightUnit,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _heightController,
                                      label: heightLabel,
                                      icon: Icons.height_outlined,
                                      suffix: heightUnit,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Age & Gender
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _ageController,
                                      label: l10n.age,
                                      icon: Icons.cake_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropdown<Gender>(
                                      value: _gender,
                                      label: l10n.gender,
                                      icon: Icons.person_outline,
                                      items: Gender.values,
                                      itemLabel: (g) => _genderLabel(g),
                                      onChanged: (v) =>
                                          setState(() => _gender = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Activity Level
                              _buildDropdown<ActivityLevel>(
                                value: _activityLevel,
                                label: l10n.activityLevel,
                                icon: Icons.directions_run_outlined,
                                items: ActivityLevel.values,
                                itemLabel: (a) => _activityLabel(a),
                                onChanged: (v) =>
                                    setState(() => _activityLevel = v),
                              ),
                              const SizedBox(height: 12),

                              // Goal
                              _buildDropdown<Goal>(
                                value: _goal,
                                label: l10n.goal,
                                icon: Icons.flag_outlined,
                                items: Goal.values,
                                itemLabel: (g) => _goalLabel(g),
                                onChanged: (v) => setState(() => _goal = v),
                              ),
                              const SizedBox(height: 20),

                              // Calculate Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _calculateFromProfile,
                                  icon: const Icon(Icons.auto_awesome, size: 20),
                                  label: Text(l10n.calculateCalories),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Manual Goals Section
                      FadeInSlide(
                        index: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: l10n.orSetManually,
                              icon: Icons.tune_outlined,
                            ),
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildInputField(
                                    controller: _caloriesController,
                                    label: l10n.calories,
                                    icon: Icons.local_fire_department_outlined,
                                    suffix: 'kcal',
                                    large: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MacroInput(
                                          controller: _proteinController,
                                          label: l10n.protein,
                                          color: AppTheme.protein,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MacroInput(
                                          controller: _carbsController,
                                          label: l10n.carbs,
                                          color: AppTheme.carbs,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MacroInput(
                                          controller: _fatController,
                                          label: l10n.fat,
                                          color: AppTheme.fat,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Target Weight
                      FadeInSlide(
                        index: 2,
                        child: GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: _buildInputField(
                            controller: _targetWeightController,
                            label: targetWeightLabel,
                            icon: Icons.emoji_events_outlined,
                            suffix: weightUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? suffix,
    bool large = false,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: large ? theme.textTheme.titleLarge : null,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  String _genderLabel(Gender g) {
    final l10n = AppLocalizations.of(context)!;
    switch (g) {
      case Gender.male:
        return l10n.genderMale;
      case Gender.female:
        return l10n.genderFemale;
      case Gender.other:
        return l10n.genderOther;
    }
  }

  String _activityLabel(ActivityLevel a) {
    final l10n = AppLocalizations.of(context)!;
    switch (a) {
      case ActivityLevel.sedentary:
        return l10n.activitySedentary;
      case ActivityLevel.light:
        return l10n.activityLight;
      case ActivityLevel.moderate:
        return l10n.activityModerate;
      case ActivityLevel.active:
        return l10n.activityActive;
      case ActivityLevel.veryActive:
        return l10n.activityVeryActive;
    }
  }

  String _goalLabel(Goal g) {
    final l10n = AppLocalizations.of(context)!;
    switch (g) {
      case Goal.lose:
        return l10n.goalLose;
      case Goal.maintain:
        return l10n.goalMaintain;
      case Goal.gain:
        return l10n.goalGain;
    }
  }
}

class _MacroInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _MacroInput({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            suffixText: 'g',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
