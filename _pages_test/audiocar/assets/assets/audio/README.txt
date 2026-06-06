SAMPLE DE ÁUDIO DO MOTOR (opcional)
====================================

Coloque aqui um arquivo de loop de motor real chamado:

    engine_loop.wav   (ou .ogg / .mp3 — ajuste o nome no código)

Assim que o arquivo existir, o app passa a usá-lo automaticamente:
  - Android/iOS/desktop: flutter_soloud carrega o sample e ajusta o pitch.
  - Navegador: Web Audio API decodifica e toca em loop com playbackRate.

Sem este arquivo, o app usa a SÍNTESE PROCEDURAL (fallback) e funciona normalmente.

Ajuste a constante `_sampleRefRpm` (em engine_audio_native.dart e
engine_audio_web.dart) para o RPM aproximado em que o sample foi gravado,
para o pitch ficar coerente com o tacômetro.

IMPORTANTE: use apenas áudio devidamente licenciado para uso comercial
(Requisito 6.7 / 14 da RFP — direitos de uso dos assets).
