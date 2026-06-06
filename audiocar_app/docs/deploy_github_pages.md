# Deploy no GitHub Pages

CI configurado em `.github/workflows/web-deploy.yml`. A cada **push em `main`**
o app é buildado e publicado em `https://<seu-usuario>.github.io/<nome-do-repo>/`.

O workflow usa o **nome do repositório** como base href automaticamente
(via `${{ github.event.repository.name }}`), então você só precisa decidir o
nome do repo. Recomendado: **`audiocar`**.

## Passos (uma vez só)

### 1. Criar o repositório no GitHub
- Acesse https://github.com/new
- Nome do repositório: **`audiocar`** (qualquer nome serve; o workflow se adapta)
- Visibilidade: público (Pages gratuito exige público no plano free)
- **NÃO** inicialize com README/.gitignore (o repo local já tem)

### 2. Conectar o repo local ao GitHub e fazer push
Na raiz do projeto `C:\Users\flavio.leite\AUDIOCAR`:

```powershell
git remote add origin https://github.com/<seu-usuario>/audiocar.git
git branch -M main
git push -u origin main
```

### 3. Habilitar GitHub Pages
- No GitHub, vá em **Settings → Pages**
- Em **Source**, selecione **"GitHub Actions"** (não "Deploy from a branch")
- Salve

### 4. Aguardar o deploy
- Aba **Actions** mostra o workflow rodando (~3-5 min)
- Quando termina, a URL aparece na própria página do Actions e em
  **Settings → Pages**.

## URL final

```
https://<seu-usuario>.github.io/audiocar/
```

## Atualizações futuras

Cada `git push` em `main` dispara um novo deploy automaticamente. Sem
intervenção manual.

## Notas

- **HTTPS automático** (GitHub Pages serve só em HTTPS) — áudio Web Audio e
  geolocalização funcionam.
- **Limites grátis:** 1 GB de site, 100 GB de banda/mês. O bundle hoje é ~58 MB.
- **Repo precisa ser público** para o tier grátis (privado exige GitHub Pro).
- O `.github/workflows/ci.yml` (analyze + test) continua valendo para PRs.
