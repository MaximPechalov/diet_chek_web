import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _noSugar = false;
  bool _keto = false;
  bool _lowFodmap = false;
  bool _lactoseFree = false;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.receipt_long,
      title: 'Сканируйте чеки',
      description: 'Фотографируйте чек из магазина\nи получайте мгновенный анализ продуктов\nпо вашим диетам',
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.menu_book,
      title: 'Анализируйте состав',
      description: 'Сканируйте состав на упаковке\nи узнавайте, какие ингредиенты\nвам не подходят',
      color: const Color(0xFFFF7043),
    ),
    _OnboardingPage(
      icon: Icons.tune,
      title: 'Выберите диеты',
      description: 'Настройте диеты, которые вы соблюдаете,\nи приложение будет проверять\nпродукты автоматически',
      color: const Color(0xFF42A5F5),
      showDietSelection: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text('Пропустить'),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (int index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (BuildContext context, int index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (int index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? AppColors.primary
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finishOnboarding();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Далее' : 'Начать',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: page.color),
          ),
          const SizedBox(height: 40),

          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          if (page.showDietSelection) ...[
            const SizedBox(height: 40),
            _buildDietSwitch(
              icon: Icons.no_food,
              label: 'Без добавленного сахара',
              color: const Color(0xFF42A5F5),
              value: _noSugar,
              onChanged: (bool value) => setState(() => _noSugar = value),
            ),
            _buildDietSwitch(
              icon: Icons.egg,
              label: 'Кето / Низкоуглеводная',
              color: const Color(0xFFFF7043),
              value: _keto,
              onChanged: (bool value) => setState(() => _keto = value),
            ),
            _buildDietSwitch(
              icon: Icons.healing,
              label: 'Low-FODMAP',
              color: const Color(0xFFAB47BC),
              value: _lowFodmap,
              onChanged: (bool value) => setState(() => _lowFodmap = value),
            ),
            _buildDietSwitch(
              icon: Icons.water_drop,
              label: 'Без лактозы',
              color: const Color(0xFF26A69A),
              value: _lactoseFree,
              onChanged: (bool value) => setState(() => _lactoseFree = value),
            ),
          ],
        ],
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
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
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