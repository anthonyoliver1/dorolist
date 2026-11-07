import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'adaptive.dart';
import '../app/productivity_scope.dart';
import '../models/task.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/time_page.dart';
import '../pages/summary_page.dart';

class NavigationBottomBar extends StatefulWidget {
  const NavigationBottomBar({super.key, this.pages})
      : assert(pages == null || pages.length == 3);

  final List<Widget>? pages;

  @override
  State<NavigationBottomBar> createState() => _NavigationBottomBarState();
}

class _NavigationBottomBarState extends State<NavigationBottomBar> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;
  final _cupertinoTabs = CupertinoTabController();
  ProductivityScope? _scope;

  @override
  void initState() {
    super.initState();
    if (widget.pages != null) {
      _pages = widget.pages!;
      return;
    }
    final scope = _scope = ProductivityScope(
      onOpenFocus: () {
        if (mounted) _onItemTapped(1);
      },
      onOpenFocusFromLiveActivity: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onItemTapped(1);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
    _pages = [
      MyHomePage(
          controller: scope.tasks,
          onFocusTask: _focusTask,
          pomodoro: scope.pomodoro,
          onOpenFocus: () => _onItemTapped(1)),
      TimePage(controller: scope.pomodoro, tasksController: scope.tasks),
      SummaryPage.withViewModel(viewModel: scope.summary),
    ];
  }

  void _focusTask(Task task) {
    if (!_scope!.pomodoro.focusOn(task)) {
      showAppMessage(
          context, 'Reinicie a sessão atual antes de trocar de tarefa.');
      return;
    }
    _onItemTapped(1);
  }

  @override
  void dispose() {
    _scope?.dispose();
    _cupertinoTabs.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _cupertinoTabs.index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertino(context)) {
      final colors = Theme.of(context).colorScheme;
      return ColoredBox(
          color: colors.surface,
          child: SafeArea(
              top: false,
              bottom: false,
              child: CupertinoTabScaffold(
                controller: _cupertinoTabs,
                backgroundColor: colors.surface,
                tabBar: CupertinoTabBar(
                  onTap: _onItemTapped,
                  height: 48,
                  iconSize: 26,
                  activeColor: colors.primary,
                  inactiveColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surface,
                  items: const [
                    BottomNavigationBarItem(
                        icon:
                            _CupertinoTabIcon(CupertinoIcons.checkmark_square),
                        activeIcon: _CupertinoTabIcon(
                            CupertinoIcons.checkmark_square_fill),
                        label: 'Tarefas'),
                    BottomNavigationBarItem(
                        icon: _CupertinoTabIcon(CupertinoIcons.timer),
                        activeIcon:
                            _CupertinoTabIcon(CupertinoIcons.timer_fill),
                        label: 'Foco'),
                    BottomNavigationBarItem(
                        icon: _CupertinoTabIcon(CupertinoIcons.chart_bar),
                        activeIcon:
                            _CupertinoTabIcon(CupertinoIcons.chart_bar_fill),
                        label: 'Resumo'),
                  ],
                ),
                tabBuilder: (context, index) =>
                    CupertinoTabView(builder: (_) => _pages[index]),
              )));
    }
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        maintainBottomViewPadding: true,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Tarefas',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.watch_later),
            label: 'Foco',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Resumo',
          ),
        ],
      ),
    );
  }
}

// Keep the labels above the system inset while bringing icons closer to them.
class _CupertinoTabIcon extends StatelessWidget {
  const _CupertinoTabIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: Icon(icon));
}
