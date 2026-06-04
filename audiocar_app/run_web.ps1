# Executa o AUDIOCAR no Chrome COM áudio habilitado.
#
# Por que este script existe:
# O motor de áudio (flutter_soloud) usa um audio worker baseado em
# SharedArrayBuffer. Navegadores só liberam SharedArrayBuffer quando a página
# é "cross-origin isolated", o que exige os cabeçalhos COOP/COEP abaixo.
# O servidor padrão do `flutter run` NÃO os envia — por isso o áudio aparece
# como "indisponível" no navegador. No celular (Android/iOS) isso não se aplica:
# o áudio é nativo e funciona sem nenhum ajuste.

$flutter = "C:\Users\flavio.leite\flutter\bin\flutter.bat"

& $flutter run -d chrome `
  --web-header "Cross-Origin-Opener-Policy=same-origin" `
  --web-header "Cross-Origin-Embedder-Policy=require-corp"

# Depois que o app abrir: clique em "Ativar áudio" (gesto exigido pelo
# navegador) e mova o slider de velocidade para ouvir o motor reagir.
