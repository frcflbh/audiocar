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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CockpitColors.panel,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Garagem · Sons de Motores',
                  style: TextStyle(
                      color: CockpitColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            for (final p in soundCatalog.profiles)
              _garageTile(p, hasPremium),
            const SizedBox(height: 12),
          ],
        );
      },
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
          setState(() => _status =
              '${p.name} é premium · ative no menu de conta');
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

  /// Cicla entre as fontes de velocidade: Demo → GPS → OBD2 → Demo.
  /// Demonstra a abstração [SpeedSource] (Seção 10 da RFP): a UI e o áudio
  /// independem da origem do dado.
  Future<void> _cycleMode() async {
    await _enableAudio(); // gesto do usuário → bom momento p/ ligar o áudio
    // Para a fonte atual.
    await _gpsSource.stop();
    await _obd2Source.stop();

    switch (_origin) {
      case SpeedOrigin.demo:
        final ok = await _gpsSource.prepare();
        if (!ok) {
          setState(() => _status =
              'Permissão de GPS negada · permanecendo em modo demo');
          await _attachSource(_demoSource, SpeedOrigin.demo);
          return;
        }
        await _attachSource(_gpsSource, SpeedOrigin.gps);
        setState(() => _status = 'GPS ativo · velocidade real');
        break;
      case SpeedOrigin.gps:
        // OBD2 é um recurso premium (Requisitos 4.6 e 11 da RFP).
        if (!(authService.user?.isPremium ?? false)) {
          await _gpsSource.stop();
          await _attachSource(_demoSource, SpeedOrigin.demo);
          setState(() => _status =
              'OBD2 é premium · ative no menu de conta');
          return;
        }
        final ok = await _obd2Source.prepare();
        if (!ok) {
          setState(() => _status = 'OBD2 não conectado · voltando ao demo');
          await _attachSource(_demoSource, SpeedOrigin.demo);
          return;
        }
        await _attachSource(_obd2Source, SpeedOrigin.obd2);
        setState(() => _status = 'OBD2 (simulado) · leitura da ECU');
        break;
      case SpeedOrigin.obd2:
        await _attachSource(_demoSource, SpeedOrigin.demo);
        setState(() => _status = 'Modo demonstração');
        break;
    }
  }

  String get _modeLabel => switch (_origin) {
        SpeedOrigin.demo => 'Demo',
        SpeedOrigin.gps => 'GPS',
        SpeedOrigin.obd2 => 'OBD2',
      };

  String get _nextModeLabel => switch (_origin) {
        SpeedOrigin.demo => 'Usar GPS',
        SpeedOrigin.gps => 'Usar OBD2',
        SpeedOrigin.obd2 => 'Modo demo',
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
              const SizedBox(height: 8),
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
              if (_demoMode) const SizedBox(height: 10),
              // Rodapé de status (toque abre a Garagem / Sons de Motores).
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _status,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: CockpitColors.textMuted, fontSize: 12),
          ),
        ),
        if (!_audioReady)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _enableAudio,
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('Ativar áudio'),
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: _cycleMode,
          icon: Icon(
            switch (_origin) {
              SpeedOrigin.demo => Icons.gps_fixed,
              SpeedOrigin.gps => Icons.cable,
              SpeedOrigin.obd2 => Icons.videogame_asset,
            },
            size: 18,
          ),
          label: Text(_nextModeLabel),
        ),
        const SizedBox(width: 8),
        _accountMenu(),
      ],
    );
  }

  Widget _accountMenu() {
    final user = authService.user;
    final initial = (user?.email.isNotEmpty ?? false)
        ? user!.email[0].toUpperCase()
        : '?';
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      onSelected: (value) {
        switch (value) {
          case 'premium':
            authService.upgradeToPremium();
            setState(() => _status = 'Premium ativado · OBD2 liberado');
            break;
          case 'logout':
            authService.signOut();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(user?.email ?? '—',
              style: const TextStyle(color: CockpitColors.textMuted)),
        ),
        if (!(user?.isPremium ?? false))
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
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: (user?.isPremium ?? false)
            ? CockpitColors.accent
            : CockpitColors.accentSoft,
        child: Text(initial,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
