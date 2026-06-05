import 'dart:async';
import 'package:flutter/material.dart';

import '../core/engine_profile.dart';
import '../core/rpm_model.dart';
import '../services/auth_service.dart';
import '../services/demo_speed_source.dart';
import '../services/sound_catalog_service.dart';
import '../services/engine_audio.dart';
import '../services/gps_service.dart';
import '../services/obd2_speed_source.dart';
import '../services/speed_source.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'widgets/car_3d_view.dart';
import 'widgets/rpm_gauge.dart';
import 'widgets/speedometer_gauge.dart';
import 'widgets/status_footer.dart';

/// Dashboard cockpit — integra GPS → RPM → áudio → visual
/// (Seções 4, 5 e 8 da RFP).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RpmModel _rpmModel = RpmModel();
  EngineProfile? _profile; // perfil selecionado do banco "Sons de Motores"
  final EngineAudio _engine = createEngineAudio();

  final DemoSpeedSource _demoSource = DemoSpeedSource();
  final GpsSpeedSource _gpsSource = GpsSpeedSource();
  final Obd2SpeedSource _obd2Source = Obd2SpeedSource();
  StreamSubscription<SpeedSample>? _speedSub;

  Timer? _ticker; // loop de animação/áudio (~30 Hz)

  // Estado físico.
  double _targetSpeed = 0; // alvo vindo da fonte de velocidade
  double _displaySpeed = 0; // valor suavizado exibido
  double _displayRpm = RpmModel.idleRpm;

  bool _audioReady = false;
  String _status = 'Inicializando…';
  SpeedOrigin _origin = SpeedOrigin.demo;

  bool get _demoMode => _origin == SpeedOrigin.demo;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _loadCatalog() async {
    if (!soundCatalog.isLoaded) {
      try {
        await soundCatalog.load();
      } catch (_) {
        return;
      }
    }
    if (soundCatalog.profiles.isNotEmpty) {
      _selectProfile(soundCatalog.profiles.first, notify: false);
    }
  }

  void _selectProfile(EngineProfile profile, {bool notify = true}) {
    _profile = profile;
    _rpmModel = RpmModel.fromProfile(profile);
    _displayRpm = profile.idleRpm;
    if (notify && mounted) setState(() {});
  }

  Future<void> _openGarage() async {
    final hasPremium = authService.user?.isPremium ?? false;
    final all = soundCatalog.profiles;
    final unlocked =
        all.where((p) => !soundCatalog.isLocked(p, hasPremium: hasPremium)).toList();
    final locked =
        all.where((p) => soundCatalog.isLocked(p, hasPremium: hasPremium)).toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: CockpitColors.panel,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CockpitColors.gaugeTrack,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Garagem · Sons de Motores',
                          style: TextStyle(
                              color: CockpitColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final p in unlocked) _garageTile(p, hasPremium),
                        if (locked.isNotEmpty)
                          _premiumBanner(locked.length, hasPremium),
                        for (final p in locked) _garageTile(p, hasPremium),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _premiumBanner(int count, bool hasPremium) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CockpitColors.accentSoft, CockpitColors.panel],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: CockpitColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: CockpitColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sons Premium',
                    style: TextStyle(
                        color: CockpitColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                Text('Desbloqueie $count motores exclusivos',
                    style: const TextStyle(
                        color: CockpitColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (authService.isGuest) {
                _openLogin(reason: 'Entre para comprar packs premium');
              } else {
                authService.upgradeToPremium();
                setState(() => _status = 'Premium ativado · sons liberados');
              }
            },
            child: Text(hasPremium ? 'Ver' : 'Desbloquear'),
          ),
        ],
      ),
    );
  }

  Widget _garageTile(EngineProfile p, bool hasPremium) {
    final locked = soundCatalog.isLocked(p, hasPremium: hasPremium);
    final pack = soundCatalog.packById(p.packId);
    final selected = _profile?.id == p.id;
    return ListTile(
      leading: Icon(
        locked ? Icons.lock : Icons.directions_car,
        color: locked ? CockpitColors.textMuted : CockpitColors.accent,
      ),
      title: Text(p.name,
          style: const TextStyle(color: CockpitColors.textPrimary)),
      subtitle: Text('${p.specLabel} · ${pack?.name ?? ''}',
          style: const TextStyle(color: CockpitColors.textMuted, fontSize: 12)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: CockpitColors.accent)
          : (locked
              ? Text(pack?.priceLabel ?? '',
                  style: const TextStyle(color: CockpitColors.textMuted))
              : null),
      onTap: () {
        if (locked) {
          Navigator.pop(context);
          if (authService.isGuest) {
            _openLogin(reason: 'Entre para desbloquear "${p.name}"');
          } else {
            setState(() => _status =
                '${p.name} é premium · ative no menu de conta');
          }
          return;
        }
        _selectProfile(p);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _boot() async {
    await _loadCatalog();
    // OBS.: o áudio NÃO é iniciado aqui. Navegadores bloqueiam a criação do
    // contexto de áudio antes de um gesto do usuário (política de autoplay).
    // A inicialização ocorre em [_enableAudio], no primeiro toque.
    _status = 'Toque em "Ativar áudio" para começar';
    if (mounted) setState(() {});

    // Começa no modo demo (testável sem deslocamento).
    await _attachSource(_demoSource, SpeedOrigin.demo);

    // Loop de atualização ~30 FPS.
    _ticker = Timer.periodic(const Duration(milliseconds: 33), _tick);
  }

  /// Inicializa o motor de áudio a partir de um gesto do usuário.
  /// Atende à política de autoplay dos navegadores e é inofensivo no mobile.
  Future<void> _enableAudio() async {
    if (_audioReady) return;
    try {
      await _engine.init();
      if (!mounted) return;
      setState(() {
        _audioReady = true;
        _status = 'Áudio ativo · $_modeLabel';
      });
    } catch (e, st) {
      debugPrint('AUDIOCAR · falha ao iniciar áudio: $e\n$st');
      if (!mounted) return;
      setState(() => _status = 'Áudio indisponível: $e');
    }
  }

  Future<void> _attachSource(SpeedSource source, SpeedOrigin origin) async {
    await _speedSub?.cancel();
    _origin = origin;
    _speedSub = source.stream.listen((sample) {
      _targetSpeed = sample.kmh;
    });
    await source.start();
  }

  void _tick(Timer _) {
    // Suavização (interpolação) para ponteiros e áudio fluidos.
    _displaySpeed += (_targetSpeed - _displaySpeed) * 0.12;
    final double targetRpm = _rpmModel.rpmForSpeed(_displaySpeed);
    _displayRpm += (targetRpm - _displayRpm) * 0.18;

    if (_audioReady) {
      _engine.update(
        rpm: _displayRpm,
        throttle: _rpmModel.throttleForRpm(_displayRpm),
      );
    }
    if (mounted) setState(() {});
  }

  /// Seleciona a fonte de velocidade (Demo / GPS / OBD2) pelo seletor.
  /// Demonstra a abstração [SpeedSource] (Seção 10 da RFP): UI e áudio
  /// independem da origem do dado.
  Future<void> _setMode(SpeedOrigin target) async {
    await _enableAudio(); // gesto do usuário → bom momento p/ ligar o áudio
    if (target == _origin && _speedSub != null) return;

    await _gpsSource.stop();
    await _obd2Source.stop();

    switch (target) {
      case SpeedOrigin.demo:
        await _attachSource(_demoSource, SpeedOrigin.demo);
        setState(() => _status = 'Modo demonstração');
        break;
      case SpeedOrigin.gps:
        final ok = await _gpsSource.prepare();
        if (!ok) {
          await _attachSource(_demoSource, SpeedOrigin.demo);
          setState(() => _status = 'Permissão de GPS negada · modo demo');
          return;
        }
        await _attachSource(_gpsSource, SpeedOrigin.gps);
        setState(() => _status = 'GPS ativo · velocidade real');
        break;
      case SpeedOrigin.obd2:
        // OBD2 é premium (Requisitos 4.6 e 11): exige login + premium.
        if (authService.isGuest) {
          await _attachSource(_demoSource, SpeedOrigin.demo);
          setState(() => _status = 'Modo demonstração');
          _openLogin(reason: 'Entre para usar o OBD2 (recurso premium)');
          return;
        }
        if (!(authService.user?.isPremium ?? false)) {
          await _attachSource(_demoSource, SpeedOrigin.demo);
          setState(() => _status = 'OBD2 é premium · ative no menu de conta');
          return;
        }
        final ok = await _obd2Source.prepare();
        if (!ok) {
          await _attachSource(_demoSource, SpeedOrigin.demo);
          setState(() => _status = 'OBD2 não conectado · modo demo');
          return;
        }
        await _attachSource(_obd2Source, SpeedOrigin.obd2);
        setState(() => _status = 'OBD2 (simulado) · leitura da ECU');
        break;
    }
  }

  /// Abre a tela de login como rota (convidado-primeiro).
  Future<void> _openLogin({String? reason}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => LoginScreen(reason: reason)),
    );
    if (mounted) setState(() {});
  }

  String get _modeLabel => switch (_origin) {
        SpeedOrigin.demo => 'Demo',
        SpeedOrigin.gps => 'GPS',
        SpeedOrigin.obd2 => 'OBD2',
      };

  @override
  void dispose() {
    _ticker?.cancel();
    _speedSub?.cancel();
    _engine.dispose();
    _demoSource.dispose();
    _gpsSource.dispose();
    _obd2Source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int gear = _rpmModel.gearForSpeed(_displaySpeed);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _topBar(),
              _statusLine(),
              const SizedBox(height: 6),
              // Modelo 3D (topo).
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Car3DView(rpm: _displayRpm),
                ),
              ),
              const SizedBox(height: 10),
              // HUD digital de velocidade (centro).
              _hud(),
              const SizedBox(height: 10),
              // Gauges (base).
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(child: SpeedometerGauge(value: _displaySpeed)),
                    const SizedBox(width: 12),
                    Expanded(child: RpmGauge(value: _displayRpm)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_demoMode) _demoSlider(),
              if (_demoMode) const SizedBox(height: 8),
              _modeSelector(),
              const SizedBox(height: 10),
              // Rodapé (toque abre a Garagem / Sons de Motores).
              GestureDetector(
                onTap: _openGarage,
                child: StatusFooter(
                  mode: _modeLabel,
                  vehicle: _profile?.name ?? 'Selecionar',
                  gear: gear,
                  obd2Connected: _origin == SpeedOrigin.obd2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Text(
          'AUDIOCAR',
          style: TextStyle(
            color: CockpitColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        _audioButton(),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _openGarage,
          icon: const Icon(Icons.garage, color: CockpitColors.textMuted),
          tooltip: 'Garagem',
        ),
        const SizedBox(width: 2),
        _accountMenu(),
      ],
    );
  }

  Widget _statusLine() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _status,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: CockpitColors.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _audioButton() {
    if (_audioReady) {
      return const IconButton(
        onPressed: null,
        icon: Icon(Icons.volume_up, color: CockpitColors.accent),
        tooltip: 'Áudio ativo',
      );
    }
    return FilledButton.tonalIcon(
      onPressed: _enableAudio,
      icon: const Icon(Icons.volume_up, size: 18),
      label: const Text('Áudio'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _modeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<SpeedOrigin>(
        segments: const [
          ButtonSegment(
              value: SpeedOrigin.demo,
              label: Text('Demo'),
              icon: Icon(Icons.videogame_asset, size: 16)),
          ButtonSegment(
              value: SpeedOrigin.gps,
              label: Text('GPS'),
              icon: Icon(Icons.gps_fixed, size: 16)),
          ButtonSegment(
              value: SpeedOrigin.obd2,
              label: Text('OBD2'),
              icon: Icon(Icons.cable, size: 16)),
        ],
        selected: {_origin},
        showSelectedIcon: false,
        onSelectionChanged: (s) => _setMode(s.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _accountMenu() {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        final user = authService.user;
        final guest = authService.isGuest;
        final initial = (!guest && user!.email.isNotEmpty)
            ? user.email[0].toUpperCase()
            : null;

        return PopupMenuButton<String>(
          tooltip: 'Conta',
          onSelected: (value) async {
            switch (value) {
              case 'login':
                _openLogin();
                break;
              case 'premium':
                authService.upgradeToPremium();
                setState(() => _status = 'Premium ativado · OBD2 liberado');
                break;
              case 'logout':
                await authService.signOut();
                if (mounted) setState(() => _status = 'Sessão encerrada');
                break;
            }
          },
          itemBuilder: (context) {
            if (guest) {
              return const [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('Você está como convidado',
                      style: TextStyle(color: CockpitColors.textMuted)),
                ),
                PopupMenuItem<String>(
                  value: 'login',
                  child: Row(children: [
                    Icon(Icons.login, size: 18),
                    SizedBox(width: 8),
                    Text('Entrar / Criar conta'),
                  ]),
                ),
              ];
            }
            return [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(user!.email,
                    style: const TextStyle(color: CockpitColors.textMuted)),
              ),
              if (!user.isPremium)
                const PopupMenuItem<String>(
                  value: 'premium',
                  child: Row(children: [
                    Icon(Icons.workspace_premium, size: 18),
                    SizedBox(width: 8),
                    Text('Tornar Premium'),
                  ]),
                )
              else
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Row(children: [
                    Icon(Icons.verified, size: 18, color: CockpitColors.accent),
                    SizedBox(width: 8),
                    Text('Premium ativo'),
                  ]),
                ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('Sair'),
                ]),
              ),
            ];
          },
          child: CircleAvatar(
            radius: 16,
            backgroundColor: guest
                ? CockpitColors.gaugeTrack
                : (user!.isPremium
                    ? CockpitColors.accent
                    : CockpitColors.accentSoft),
            child: initial != null
                ? Text(initial,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))
                : const Icon(Icons.person,
                    size: 18, color: CockpitColors.textMuted),
          ),
        );
      },
    );
  }

  Widget _hud() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: CockpitColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: CockpitColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            _displaySpeed.round().toString(),
            style: const TextStyle(
              color: CockpitColors.accent,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const Text('km/h · HUD',
              style:
                  TextStyle(color: CockpitColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _demoSlider() {
    return Row(
      children: [
        const Icon(Icons.speed, size: 18, color: CockpitColors.textMuted),
        Expanded(
          child: Slider(
            value: _targetSpeed.clamp(0, 240),
            min: 0,
            max: 240,
            onChanged: (v) {
              if (!_audioReady) _enableAudio();
              _demoSource.setSpeed(v);
            },
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${_targetSpeed.round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: CockpitColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
