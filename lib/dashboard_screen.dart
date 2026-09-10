import 'dart:math' as math;

import 'package:flutter/material.dart';

// Cores do painel. As cores do login ficam em brand.dart.
const _background = Color(0xFF15142F);
const _surface = Color(0xFF242144);
const _card = Color(0xFF191733);
const _muted = Color(0xFFA39DBF);
const _cyan = Color(0xFF36C9D8);
const _green = Color(0xFF65D99A);

// Dados que cada cartão precisa para mostrar um pivô.
class _Pivot {
  const _Pivot(this.name, this.active, this.hours, this.area);
  final String name;
  final bool active;
  final String hours;
  final String area;
}

// Valores definidos aqui no código. Quando os equipamentos forem conectados,
// esta lista deverá receber os dados enviados por eles.
const _pivots = [
  _Pivot('Pivô Leste', true, '3h45', '42 ha'),
  _Pivot('Pivô Oeste', true, '2h30', '38 ha'),
  _Pivot('Pivô Norte', false, '0h00', '56 ha'),
  _Pivot('Pivô Sul', true, '4h10', '45 ha'),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
  });
  final String name;
  final String email;
  final void Function(BuildContext) onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0: início, 1: pivôs, 2: perfil, 3: relatórios.
  int _tab = 0;

  void _notifications() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notificações'),
        content: const Text('Nenhuma notificação no momento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  // Abre os detalhes do pivô em uma janela na parte de baixo da tela.
  void _details(_Pivot pivot) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pivot.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _detailRow('Status', pivot.active ? 'Operando' : 'Desativado'),
              _detailRow('Tempo de operação hoje', pivot.hours),
              _detailRow('Área de cobertura', pivot.area),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _cyan,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _background,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_background, Color(0xFF282347)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  children: [
                    _header(),
                    const SizedBox(height: 26),
                    if (_tab == 0) _home(),
                    if (_tab == 1) _pivotList(),
                    if (_tab == 2) _profile(),
                    if (_tab == 3) _reports(),
                    const SizedBox(height: 24),
                    const Text(
                      'GHYDRO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF444064))),
            gradient: LinearGradient(
              colors: [Color(0xFF222444), Color(0xFF30264F)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  indicatorColor: _cyan.withValues(alpha: 0.14),
                  selectedIndex: _tab,
                  onDestinationSelected: (value) =>
                      setState(() => _tab = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded, color: _cyan),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.water_drop_outlined),
                      selectedIcon: Icon(Icons.water_drop, color: _cyan),
                      label: 'Pivôs',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person, color: _cyan),
                      label: 'Perfil',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_rounded),
                      selectedIcon: Icon(Icons.bar_chart_rounded, color: _cyan),
                      label: 'Relatórios',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mostra o nome da conta, as notificações e a opção de sair.
  Widget _header() => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _cyan.withValues(alpha: 0.7), width: 2),
          color: _surface,
        ),
        child: Center(
          child: Text(
            widget.name.trim().isEmpty
                ? 'G'
                : widget.name.trim().characters.first.toUpperCase(),
            style: const TextStyle(
              fontSize: 23,
              color: _cyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bem-vindo!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Notificações',
        onPressed: _notifications,
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: Color(0xFFE2DDF6),
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Mais opções',
        icon: const Icon(Icons.more_vert, color: _muted),
        onSelected: (value) {
          if (value == 'logout') widget.onLogout(context);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'logout', child: Text('Sair da conta')),
        ],
      ),
    ],
  );

  // No computador, coloca resumo e pivôs lado a lado.
  // No celular, organiza tudo em uma coluna.
  Widget _home() => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 760) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [_economy(), const SizedBox(height: 24), _overview()],
              ),
            ),
            const SizedBox(width: 36),
            Expanded(child: _pivotList()),
          ],
        );
      }
      return Column(
        children: [_economy(), const SizedBox(height: 28), _pivotList()],
      );
    },
  );

  // Os valores de economia estão fixos até a conexão com a fonte de dados.
  Widget _economy() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [
          const Color(0xFF343056).withValues(alpha: 0.7),
          _background.withValues(alpha: 0),
        ],
        radius: 0.75,
      ),
    ),
    child: Column(
      children: [
        const Text(
          'SUA IRRIGAÇÃO, MAIS EFICIENTE',
          style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.8),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Economia mensal: 5.643 reais e 50 centavos. 78 por cento da meta.',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _EconomyRing(),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R\$ 5.643,50',
                        style: TextStyle(
                          color: _green,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Economia mensal',
                        style: TextStyle(color: _muted, fontSize: 14),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '78% da meta',
                        style: TextStyle(color: _cyan, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, color: _green, size: 17),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                '12,8% em relação ao mês anterior',
                textAlign: TextAlign.center,
                style: TextStyle(color: _green, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _pivotList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Seus pivôs',
              style: TextStyle(
                color: Color(0xFFE7E2F6),
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '3 operando',
              style: TextStyle(color: _green, fontSize: 11),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      for (final pivot in _pivots)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _pivotCard(pivot),
        ),
    ],
  );

  // Reaproveita o mesmo cartão para cada item da lista.
  Widget _pivotCard(_Pivot pivot) => Material(
    color: _card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xFF393254)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _details(pivot),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        child: Row(
          children: [
            Icon(
              Icons.water_drop_outlined,
              color: pivot.active ? const Color(0xFFD9D1F5) : _muted,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pivot.name,
                    style: const TextStyle(
                      color: Color(0xFFE7E2F6),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pivot.active ? 'Operando' : 'Desativado',
                    style: TextStyle(
                      color: pivot.active ? _green : const Color(0xFFE38799),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _pill(
                  pivot.active ? '100%' : '0%',
                  Icons.speed,
                  pivot.active ? _green : _muted,
                ),
                const SizedBox(height: 5),
                _pill(pivot.hours, Icons.access_time, _muted),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // Etiqueta pequena para a porcentagem e o tempo de operação.
  Widget _pill(String value, IconData icon, Color color) => Container(
    width: 84,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF36305B)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 12)),
        Icon(icon, color: _muted, size: 15),
      ],
    ),
  );

  Widget _overview() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Visão geral',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        const SizedBox(height: 12),
        _detailRow('Área total monitorada', '181 ha'),
        _detailRow('Pivôs em operação', '3 de 4'),
        _detailRow('Água economizada no mês', '128 m³'),
      ],
    ),
  );

  // Nome e e-mail vêm da conta usada no login.
  Widget _profile() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Minha conta',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        const SizedBox(height: 24),
        const Text('Nome', style: TextStyle(color: _muted)),
        const SizedBox(height: 6),
        Text(
          widget.name,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 20),
        const Text('E-mail', style: TextStyle(color: _muted)),
        const SizedBox(height: 6),
        Text(
          widget.email,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => widget.onLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
      ],
    ),
  );

  // As alturas das barras representam valores definidos no código.
  Widget _reports() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Relatórios',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
      const SizedBox(height: 8),
      const Text(
        'Economia dos últimos 6 meses',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 28),
      Container(
        height: 230,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in const [
              ('Abr', 0.35),
              ('Mai', 0.5),
              ('Jun', 0.42),
              ('Jul', 0.65),
              ('Ago', 0.78),
              ('Set', 0.88),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: entry.$2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFF6634CE), _cyan],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        entry.$1,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _overview(),
    ],
  );
}

// Desenha o anel direto na tela, sem precisar de uma imagem.
class _EconomyRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.39;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = size.width * 0.095;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF302B50);
    canvas.drawCircle(center, radius, track);
    canvas.drawCircle(
      center,
      radius + stroke / 2 + 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF3B355A),
    );
    const start = -math.pi / 6;
    const sweep = math.pi * 2 * 0.78;
    // Deixa a emenda do degradê no espaço vazio do anel.
    // Assim, a ponta verde não recebe um pedaço da cor rosa.
    const gapHalf = (math.pi * 2 - sweep) / 2;
    final gradient = SweepGradient(
      startAngle: gapHalf,
      endAngle: gapHalf + sweep,
      transform: const GradientRotation(start - gapHalf),
      colors: const [
        _green,
        _cyan,
        Color(0xFF116DDE),
        Color(0xFF5914CC),
        Color(0xFFA82AF2),
      ],
      stops: const [0, 0.3, 0.52, 0.75, 1],
    ).createShader(rect);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawArc(rect, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _EconomyRing oldDelegate) => false;
}
