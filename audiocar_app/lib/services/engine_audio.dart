// Ponto único de entrada do motor de áudio.
//
// Seleciona a implementação correta em tempo de compilação:
//   - Navegador (dart.library.js_interop) → Web Audio API
//   - Demais plataformas                  → flutter_soloud (nativo)
export 'engine_audio_interface.dart';

import 'engine_audio_interface.dart';
import 'engine_audio_native.dart'
    if (dart.library.js_interop) 'engine_audio_web.dart' as impl;

EngineAudio createEngineAudio() => impl.createEngineAudio();
