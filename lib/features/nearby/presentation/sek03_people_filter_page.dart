import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_models.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-03 Filter Orang: marga, kota, kampus/kantor, dan hobi (PRD 5.1, 6.3).
class Sek03PeopleFilterPage extends ConsumerStatefulWidget {
  const Sek03PeopleFilterPage({super.key});

  @override
  ConsumerState<Sek03PeopleFilterPage> createState() =>
      _Sek03PeopleFilterPageState();
}

class _Sek03PeopleFilterPageState extends ConsumerState<Sek03PeopleFilterPage> {
  String? _selectedCity;
  String? _selectedMarga;
  late final TextEditingController _campusCtrl;
  late final TextEditingController _hobbyCtrl;

  static const List<String> _quickHobbies = <String>[
    'Badminton',
    'Futsal',
    'Kopi',
    'Jogging',
    'Basket',
    'Musik Batak',
  ];

  @override
  void initState() {
    super.initState();
    final filter = ref.read(nearbyControllerProvider).filter;
    _selectedCity = filter.city;
    _selectedMarga = filter.marga;
    _campusCtrl = TextEditingController(text: filter.campusOrOffice ?? '');
    _hobbyCtrl = TextEditingController(text: filter.hobby ?? '');
  }

  @override
  void dispose() {
    _campusCtrl.dispose();
    _hobbyCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final controller = ref.read(nearbyControllerProvider.notifier);
    await controller.applyFilter(
      NearbyPeopleFilter(
        city: _selectedCity,
        marga: _selectedMarga,
        campusOrOffice: _campusCtrl.text.trim().isEmpty
            ? null
            : _campusCtrl.text.trim(),
        hobby: _hobbyCtrl.text.trim().isEmpty ? null : _hobbyCtrl.text.trim(),
      ),
    );
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _reset() async {
    setState(() {
      _selectedCity = null;
      _selectedMarga = null;
      _campusCtrl.clear();
      _hobbyCtrl.clear();
    });
    await ref.read(nearbyControllerProvider.notifier).resetFilter();
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyControllerProvider);
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sek03Title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          Text(AppStrings.sek03CityLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String?>(
            initialValue: _selectedCity,
            decoration: const InputDecoration(),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(AppStrings.sek03AllCities),
              ),
              for (final city in state.availableCities)
                DropdownMenuItem<String?>(
                  value: city.name,
                  child: Text(city.name),
                ),
            ],
            onChanged: (val) => setState(() => _selectedCity = val),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.sek03MargaLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String?>(
            initialValue: _selectedMarga,
            decoration: const InputDecoration(),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(AppStrings.sek03AllMargas),
              ),
              for (final m in state.availableMargas)
                DropdownMenuItem<String?>(value: m.name, child: Text(m.name)),
            ],
            onChanged: (val) => setState(() => _selectedMarga = val),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _campusCtrl,
            label: AppStrings.sek03CampusOrOfficeLabel,
            hintText: AppStrings.sek03CampusOrOfficeHint,
            leadingIcon: Icons.school_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _hobbyCtrl,
            label: AppStrings.sek03HobbyLabel,
            hintText: AppStrings.sek03HobbyHint,
            leadingIcon: Icons.sports_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final hobby in _quickHobbies)
                AppChip(
                  label: hobby,
                  isSelected:
                      _hobbyCtrl.text.trim().toLowerCase() ==
                      hobby.toLowerCase(),
                  onTap: () => setState(() => _hobbyCtrl.text = hobby),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: AppStrings.sek03ResetBtn,
                  variant: AppButtonVariant.secondary,
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: AppStrings.sek03ApplyBtn,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
