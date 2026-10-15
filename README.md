# Limpador Windows

Organiza a raiz da pasta Downloads e limpa arquivos temporários do Windows. Dá para rodar pelo Python ou por um executável.

## O que ele faz

- Move arquivos antigos soltos na raiz de Downloads para pastas por tipo: Imagens, PDFs, Documentos, Vídeos, Áudio, Compactados e Instaladores.
- Manda lixo óbvio (`.tmp`, `.crdownload`, `.part`, `.lock` e similares) para `Downloads\_Lixo` e apaga essa quarentena depois de 7 dias.
- Apaga arquivos com mais de 1 dia em `%TEMP%`, `C:\Windows\Temp` e `%LOCALAPPDATA%\CrashDumps`, pulando o que estiver em uso.
- Apaga os `.pf` de `C:\Windows\Prefetch` na limpeza manual. O modo `--vigiar` não mexe no Prefetch.
- Mostra no final quantos MB foram liberados. Mover um arquivo de Downloads não entra nessa conta.

Pastas que você já criou dentro de Downloads não são percorridas. Instalador antigo é só movido; nenhum programa é desinstalado.

O Windows recria arquivos `.pf` quando um programa abre. A pasta Prefetch não fica vazia para sempre.

## Requisitos

- Windows
- Python 3.12 ou superior para rodar o script. O executável não precisa de Python.

## Uso

Na primeira vez, sem argumentos, o script só simula:

```powershell
python limpador.py
```

Para organizar e apagar de verdade:

```powershell
python limpador.py --aplicar
```

Dois cliques em `LimpadorWindows.exe` também aplicam a limpeza. A janela espera um Enter antes de fechar.

Para limpar `C:\Windows\Temp`, abra o executável como administrador. Clique com o botão direito em `LimpadorWindows.exe` e escolha **Executar como administrador**. No PowerShell, a partir da pasta do projeto:

```powershell
Start-Process -FilePath .\LimpadorWindows.exe -Verb RunAs
```

O Windows pede confirmação antes de abrir. Sem isso, Downloads, `%TEMP%`, CrashDumps e Prefetch continuam sendo limpos, e `C:\Windows\Temp` fica de fora.

| Comando | Efeito |
| --- | --- |
| `python limpador.py` | Simula |
| `python limpador.py --aplicar` | Executa uma vez |
| `python limpador.py --vigiar` | Repete Downloads, Temp e dumps a cada 30 minutos. Prefetch fica de fora |
| `LimpadorWindows.exe` | Executa uma vez |
| `LimpadorWindows.exe --simular` | Simula |

O histórico fica em `limpador.log`, ao lado do script ou do executável.

## Segundo plano

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

Isso cria um atalho na inicialização do Windows. Se `LimpadorWindows.exe` estiver na pasta, o atalho usa o executável. Senão, usa o `pythonw`.

## Configuração

O `config.json` precisa ficar na mesma pasta do script ou do executável.

- `idade_minima_dias`: idade mínima para mexer em um arquivo de Downloads.
- `intervalo_minutos`: pausa do modo `--vigiar`.
- `apagar_lixo_apos_dias`: quanto tempo um item fica em `_Lixo`.
- `temp`, `windows_temp` e `crashdumps`: ligar ou desligar, e a idade mínima.
- `prefetch`: ligar ou desligar, e a idade mínima. `0` apaga todos os `.pf` da passagem manual.

## Gerar o executável

```powershell
python -m pip install pyinstaller
python -m PyInstaller --noconfirm --clean --onefile --console --name LimpadorWindows limpador.py
```

O arquivo sai em `dist\LimpadorWindows.exe`. Copie ele para a pasta do projeto, junto do `config.json`.

## Licença

MIT. O texto completo está no arquivo `LICENSE`.
