# Banco "Sons de Motores" — Referências e Modelo

Estudo dos apps de referência para fundamentar o banco de dados de sons de motor
do AUDIOCAR. Extraímos **estrutura e funcionalidades** (não áudios proprietários —
todo sample deve ser licenciado, conforme §14 da RFP).

## Apps de referência

### RevHeadz Engine Sounds (MWM)
Simulador standalone de som de motor para iOS/Android.
- Perfis descritos por **especificação do motor**: cilindrada + configuração +
  categoria. Ex. do pack gratuito: *6.0L V12 Italian Supercar*, *4.7L V8 American
  Classic Muscle Car*, *1.3L RX Rotary*, *1800cc V-Twin Cruiser*, *1000cc V4
  Japanese Sports Bike*, *100cc Chainsaw*.
- Física simulada: ignição start/stop, velocímetro, tacômetro, acelerador,
  **trocas de marcha**, freios, **relações de marcha (drive ratios)**, turbo,
  supercharger, **drive lashing**, **engine load**, **backfire**, pneu/burnout.
- **Packs** gratuitos + pagos (Classic V8, American Muscle, GT racing) → monetização.
- OBD2 opcional (ELM327 Wi-Fi/Bluetooth) reportando RPM ou velocidade.
- Opção MPH/KMH.
Fonte: https://apps.apple.com/us/app/revheadz-engine-sounds/id793064343 ·
http://www.revheadz.com.au/

### Wrumer (Jure Sotosek)
Abordagem **OBD2-first** (dongle + app) que toca o som pelos alto-falantes do carro.
- Lê **RPM e acelerador** via OBD2 (carros pós-2004; não funciona em elétricos).
- Seleção de sons + efeitos: **turbo whistle**, **backfires**.
- iOS e Android.
Fonte: https://us.wrumersound.com/ ·
https://play.google.com/store/apps/details?id=com.wrumer.wrumerapp

## O que adotamos no AUDIOCAR

| Conceito da referência | Como vira dado no nosso banco |
|---|---|
| Perfil por especificação (6.0L V12 …) | `EngineProfile` (cilindrada, nº cilindros, layout, categoria) |
| Drive ratios / trocas de marcha | `gearTopSpeedKmh[]` por perfil |
| Faixa de operação (idle→redline) | `idleRpm`, `redlineRpm`, `maxRpm` por perfil |
| Indução (turbo/super) | `induction` (na / turbo / supercharger) |
| Efeitos (turbo whistle, backfire) | `effects[]` (flags por perfil) |
| Packs gratuitos vs pagos | `SoundPack` (`isFree`/`priceCents`, `isPremium`) |
| Sample de áudio real | `sampleAsset`, `sampleRefRpm` por perfil |
| OBD2 (RPM/velocidade reais) | já suportado via `Obd2*Source` (Seção 7) |

## Estrutura do banco
- **EngineProfile**: 1 registro por motor (a unidade de "Sons de Motores").
- **SoundPack**: agrupa perfis para venda/distribuição (§4.3 biblioteca, §11 monetização).
- **engine_catalog.json**: catálogo versionável, carregado por `SoundCatalogService`.
  No futuro, este JSON pode vir de um endpoint remoto (download remoto de veículos,
  Requisito 4.3) sem alterar o app.

> Nomes dos perfis usam **descrições genéricas** (ex.: "V12 Supercar Italiano"),
> evitando marcas registradas. Parcerias com montadoras (§11) entram como packs
> oficiais licenciados.
