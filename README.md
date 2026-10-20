# Limpador Windows

Organiza a raiz das pastas Downloads e Área de trabalho, limpa temporários do Windows e reúne num menu as tarefas comuns de manutenção. Não precisa de Python. Roda no Prompt de Comando, que já vem no Windows.

## Como baixar

1. Abra a página de [Releases](https://github.com/Thaynoanhit/Limpador-Windows/releases).
2. Baixe o `.zip` da versão mais recente.
3. Extraia a pasta.
4. Clique em `manutencao.bat` ou `aplicar.bat`.

Cada merge na branch `main` cria uma release e uma tag novas automaticamente, com o zip pronto.

## Dois jeitos de usar

Os dois pedem permissão de administrador e os dois criam o mesmo atalho na inicialização do Windows.

| Arquivo | Para quem | O que acontece |
| --- | --- | --- |
| `manutencao.bat` | Quem quer escolher | Abre o menu e roda só a opção escolhida |
| `aplicar.bat` | Quem quer aplicar e pronto | Roda a manutenção seguida, sem perguntar |

Na primeira abertura de qualquer um dos dois, o atalho `LimpadorWindows` entra na pasta Inicializar. Na próxima entrada no Windows, a limpeza de Downloads, Área de trabalho e temporários passa a repetir sozinha a cada 30 minutos. Essa repetição não mexe no Prefetch. Se não quiser mais isso, use a opção 13 do menu. Para religar, use a 14.

O histórico detalhado fica em `limpador.log`. O clique único também grava um `relatorio-AAAAAMMDD-HHMMSS.txt` com o resumo do que rodou, o que falhou e o espaço liberado.

## O que a limpeza de arquivos faz

- Move arquivos antigos soltos na raiz de **Downloads** e da **Área de trabalho** para pastas por tipo: Imagens, PDFs, Documentos, Vídeos, Áudio, Compactados e Instaladores.
- Manda lixo óbvio (`.tmp`, `.crdownload`, `.part`, `.lock` e similares) para `_Lixo` dentro de cada pasta e apaga essa quarentena depois de 7 dias.
- Na Área de trabalho, atalhos (`.lnk` e `.url`) ficam no lugar.
- Apaga arquivos com mais de 1 dia em `%TEMP%`, `C:\Windows\Temp` e `%LOCALAPPDATA%\CrashDumps`, pulando o que estiver em uso.
- Na limpeza manual, apaga os `.pf` de `C:\Windows\Prefetch`. A repetição automática não mexe no Prefetch.

Pastas que você já criou dentro de Downloads ou da Área de trabalho não são percorridas. Instalador antigo é só movido. Nenhum programa é desinstalado.

Um arquivo só entra na organização depois de 2 dias. Mover um arquivo não entra na conta de espaço liberado. O Windows recria os `.pf` quando um programa abre, então a pasta Prefetch não fica vazia para sempre.

Sem administrador, `C:\Windows\Temp` e o Prefetch ficam de fora. O menu e o `aplicar.bat` já pedem essa permissão.

## O que o clique único executa

1. Organizar Downloads, Área de trabalho e limpar temporários
2. Limpar arquivos de atualização que não são mais necessários
3. Limpar o cache DNS
4. Esvaziar a lixeira
5. Reiniciar a fila de impressão
6. Reparar a imagem do Windows (DISM)
7. Corrigir arquivos protegidos (SFC)
8. Verificar o disco (CHKDSK online)
9. Otimizar o disco

Antes das etapas longas (DISM, SFC, CHKDSK e otimização), a janela avisa o tempo estimado e pede para não fechar. No final aparece um resumo: o que deu certo, o que falhou e quanto espaço a limpeza de arquivos liberou. O mesmo resumo vai para o arquivo `relatorio-...txt`.

## O que o menu deixa escolher

1. Simular organização de Downloads, Área de trabalho e limpeza
2. Organizar Downloads, Área de trabalho e limpar temporários
3. Limpar arquivos de atualizações desnecessários
4. Limpar cache DNS
5. Esvaziar lixeira
6. Reiniciar a fila de impressão
7. Verificar disco (CHKDSK online)
8. Verificar imagem do Windows (DISM ScanHealth)
9. Verificar arquivos protegidos (SFC verifyonly)
10. Reparar imagem do Windows (DISM RestoreHealth)
11. Corrigir arquivos do Windows (SFC scannow)
12. Otimizar disco (SSD/HD)
13. Parar limpeza automática ao ligar o PC
14. Religar limpeza automática ao ligar o PC

A opção 0 sai. As opções 1, 8 e 9 só olham o sistema. O `aplicar.bat` não as executa, para não repetir a verificação antes do reparo.

A opção 13 apaga o atalho da inicialização e grava um aviso local para o programa não recriar esse atalho na próxima abertura. A opção 14 remove esse aviso e cria o atalho de novo.

## Arquivos

- `manutencao.bat` abre o menu e contém a limpeza.
- `aplicar.bat` dispara a manutenção completa.
- `chuva.ps1` desenha a abertura em verde na primeira vez que o menu abre.
- `limpador.log` guarda o detalhe da limpeza. Não entra no Git.
- `relatorio-....txt` guarda o resumo do clique único. Não entra no Git.

## Licença

MIT. O texto completo está no arquivo `LICENSE`.
