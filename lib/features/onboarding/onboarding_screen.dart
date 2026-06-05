import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  int _currentPage = 0;

  bool _noSugar = false;
  bool _keto = false;
  bool _lowFodmap = false;
  bool _lactoseFree = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.receipt_long,
      title: 'Добро пожаловать\nв Dietio',
      description: 'Ваш персональный диетический аудитор.\nСканируйте чеки и составы продуктов\nи получайте мгновенный анализ.',
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.menu_book,
      title: 'Анализируйте\nсостав',
      description: 'Сканируйте состав на упаковке\nи узнавайте, какие ингредиенты\nвам не подходят.',
      color: const Color(0xFFFF7043),
    ),
    _OnboardingPage(
      icon: Icons.tune,
      title: 'Выберите\nдиеты',
      description: 'Настройте диеты, которые вы соблюдаете,\nи Dietio будет проверять\nпродукты автоматически.',
      color: const Color(0xFF42A5F5),
      showDietSelection: true,
    ),
  ];

  bool get _hasSelectedDiets => _noSugar || _keto || _lowFodmap || _lactoseFree;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<String> activeDiets = [];
    if (_noSugar) activeDiets.add('no_sugar');
    if (_keto) activeDiets.add('keto');
    if (_lowFodmap) activeDiets.add('low_fodmap');
    if (_lactoseFree) activeDiets.add('lactose_free');
    await prefs.setStringList('active_diets', activeDiets);

    await prefs.setBool('onboarding_complete', true);

    widget.onComplete();
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Кнопка пропуска
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                  child: const Text('Пропустить', style: TextStyle(fontSize: 15)),
                ),
              ),
            ),

            // Индикатор страниц
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentPage == index ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == index ? _pages[index].color : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),

            // Контент страниц — IndexedStack с центрированием
            Expanded(
              child: IndexedStack(
                index: _currentPage,
                children: _pages.map((page) => _buildPage(page)).toList(),
              ),
            ),

            // Кнопки навигации
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goToPreviousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _pages[_currentPage].color,
                          side: BorderSide(color: _pages[_currentPage].color.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Назад', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),

                  Expanded(
                    flex: _currentPage > 0 ? 2 : 1,
                    child: _currentPage < _pages.length - 1
                        ? ElevatedButton(
                            onPressed: _goToNextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pages[_currentPage].color,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: _pages[_currentPage].color.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Далее', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          )
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: _hasSelectedDiets
                                  ? LinearGradient(colors: [_pages[_currentPage].color, _pages[_currentPage].color.withOpacity(0.7)])
                                  : LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!]),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _finishOnboarding,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      _hasSelectedDiets ? 'Начать использовать' : 'Настрою позже',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(scale: _pulseAnimation.value, child: child);
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: page.color.withOpacity(0.3), width: 2),
                ),
                child: Icon(page.icon, size: 65, color: page.color),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              page.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              page.description,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.6),
              textAlign: TextAlign.center,
            ),
            if (page.showDietSelection) ...[
              const SizedBox(height: 40),
              _buildDietSwitch(
                icon: Icons.no_food,
                label: 'Без добавленного сахара',
                color: AppColors.noSugarCard,
                value: _noSugar,
                onChanged: (bool value) => setState(() => _noSugar = value),
              ),
              _buildDietSwitch(
                icon: Icons.egg,
                label: 'Кето / Низкоуглеводная',
                color: AppColors.ketoCard,
                value: _keto,
                onChanged: (bool value) => setState(() => _keto = value),
              ),
              _buildDietSwitch(
                icon: Icons.healing,
                label: 'Low-FODMAP',
                color: AppColors.lowFodmapCard,
                value: _lowFodmap,
                onChanged: (bool value) => setState(() => _lowFodmap = value),
              ),
              _buildDietSwitch(
                icon: Icons.water_drop,
                label: 'Без лактозы',
                color: AppColors.lactoseFreeCard,
                value: _lactoseFree,
                onChanged: (bool value) => setState(() => _lactoseFree = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDietSwitch({
    required IconData icon,
    required String label,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.15),
            width: value ? 1.5 : 1,
          ),
        ),
        child: SwitchListTile(
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: value ? color : Colors.grey[400]),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              color: value ? color : Colors.grey[700],
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool showDietSelection;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.showDietSelection = false,
  });
}