# Limpador Windows

Organiza a raiz das pastas Downloads e Área de trabalho, limpa temporários do Windows e reúne num menu as tarefas comuns de manutenção. Não precisa de Python. Roda no Prompt de Comando, que já vem no Windows.

## Como baixar

1. Abra a página de [Releases](https://github.com/Thaynoanhit/Limpador-Windows/releases).
2. Baixe o `.zip` da versão mais recente.
3. Extraia a pasta.
4. Clique em `manutencao.bat` e escolha no menu o que quer rodar.

Cada merge na branch `main` cria uma release e uma tag novas automaticamente, com o zip pronto.

## Como usar

O programa pede permissão de administrador. Nada roda sozinho: a limpeza só acontece quando alguém abre o `manutencao.bat` e escolhe uma opção.

O histórico detalhado fica em `limpador.log`. A auditoria de segurança grava `auditoria-....html` e `.json`.

## O que a limpeza de arquivos faz

- Move arquivos antigos soltos na raiz de **Downloads** e da **Área de trabalho** para pastas por tipo: Imagens, PDFs, Documentos, Vídeos, Áudio, Compactados e Instaladores.
- Manda lixo óbvio (`.tmp`, `.crdownload`, `.part`, `.lock` e similares) para `_Lixo` dentro de cada pasta e apaga essa quarentena depois de 7 dias.
- Na Área de trabalho, atalhos (`.lnk` e `.url`) ficam no lugar.
- Apaga arquivos com mais de 1 dia em `%TEMP%`, `C:\Windows\Temp` e `%LOCALAPPDATA%\CrashDumps`, pulando o que estiver em uso.
- Apaga os `.pf` de `C:\Windows\Prefetch`. O Windows recria esses arquivos quando um programa abre.

Pastas que você já criou dentro de Downloads ou da Área de trabalho não são percorridas. Instalador antigo é só movido. Nenhum programa é desinstalado.

Um arquivo só entra na organização depois de 2 dias. Mover um arquivo não entra na conta de espaço liberado. O Windows recria os `.pf` quando um programa abre, então a pasta Prefetch não fica vazia para sempre.

Sem administrador, `C:\Windows\Temp` e o Prefetch ficam de fora. O menu já pede essa permissão.

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
13. Aliviar processos em segundo plano
14. Limpar caches do sistema e da placa de vídeo
15. Tirar restos de programas desinstalados
16. Verificar vírus (Windows Defender)
17. Varredura offline contra vírus (reinicia o PC)
18. Remover apps pré-instalados (sem Xbox)
19. Privacidade (telemetria, anúncios, Cortana)
20. Performance leve (Game DVR, animações, energia)
21. Desativar serviços inúteis (inclui WSearch)
22. Otimizar Windows (bloat, privacidade, performance, serviços)
23. Auditar segurança do Windows (só leitura)
24. Corrigir falhas seguras da auditoria

A opção 0 sai. As opções 1, 8 e 9 só olham o sistema. Antes das etapas longas (DISM, SFC, CHKDSK e otimização), a janela avisa o tempo estimado.

A opção 13 pede confirmação e encerra só uma lista fixa: barra de jogos Xbox, Widgets, Vincular ao celular, OneDrive, atualizadores do Edge, do Google e da Adobe, e a telemetria de compatibilidade. Navegador, jogos, Explorer e antivírus ficam abertos. O Windows pode reabrir alguns desses itens depois.

A opção 14 pede confirmação e apaga caches que o sistema recria: shaders da placa de vídeo (DirectX, NVIDIA, AMD e Intel), miniaturas e ícones do Explorer, cache de fontes e cache de Otimização de Entrega. O navegador fica de fora de propósito. A pasta de cache do Chrome, do Edge e do Firefox fica ao lado dos cookies e da sessão, e apagar o arquivo errado desconecta as contas. O primeiro jogo depois da opção 14 pode abrir mais devagar, até a placa recriar os shaders.

A opção 15 pede confirmação e lista antes de apagar. Uma pasta só entra se o desinstalador sumiu, não restou programa dentro dela, e ela está em Arquivos de Programas ou ProgramData. Também remove a entrada fantasma em Aplicativos e o atalho de inicialização que aponta para um arquivo que não existe. AppData, pasta do usuário, navegador e componentes do Windows ficam de fora.

A opção 16 pede confirmação, atualiza as definições do Windows Defender e faz a varredura rápida. Se aparecer ameaça, o programa avisa para abrir a Segurança do Windows. A varredura do disco inteiro continua lá, porque pode levar horas.

A opção 17 pede a palavra SIM, atualiza as definições e reinicia o PC. A varredura acontece antes do Windows abrir, com o vírus parado. Salve os arquivos antes.

A opção 18 remove apps pré-instalados (Bing, Skype, Solitaire, Mapas, Feedback Hub, Vincular ao celular e similares). Xbox, Game Bar, Store, Paint e codecs de imagem ficam no lugar.

A opção 19 reduz telemetria, anúncios, Cortana e sugestões do Windows.

A opção 20 desliga Game DVR, reduz animações e ativa o plano `ChrisTitus - Ultimate Power Plan` (cria se ainda não existir): disco sem desligar, USB selective suspend off, PCI Express off e processador no máximo. Não remove Xbox nem Game Bar.

A opção 21 desativa Fax, telemetria, RemoteRegistry, WSearch e similares. Serviços Xbox, SysMain, spooler, Windows Update e Defender ficam ativos. Desligar WSearch enfraquece a busca do menu Iniciar e do Explorer.

A opção 22 pede a palavra SIM e roda as opções 18 a 21 em sequência.

A opção 23 audita o Windows (só leitura) com baseline inspirada no CIS: firewall, Defender, SMBv1, RDP, UAC, LSASS, conta Convidado (SID), política de senha, BitLocker, Secure Boot, autologon e Windows Update. Gera `auditoria-....html` e `.json` e abre o HTML.

A opção 24 pede a palavra SIM e corrige só falhas seguras: firewall, Defender em tempo real, SMBv1, RDP e conta Convidado. Não altera sozinho senha mínima, lockout nem LSASS (aparecem só como recomendação no relatório).

## Arquivos

- `manutencao.bat` abre o menu e contém a limpeza.
- `chuva.ps1` desenha a abertura em verde na primeira vez que o menu abre.
- `restos.ps1` procura restos de programas já desinstalados. O menu chama esse arquivo na opção 15.
- `otimizar.ps1` remove bloat, aplica privacidade, performance leve e desativa serviços. O menu chama esse arquivo nas opções 18 a 22.
- `auditor.ps1` audita a segurança do Windows e aplica correções seguras. O menu chama esse arquivo nas opções 23 e 24.
- `limpador.log` guarda o detalhe da limpeza. Não entra no Git.
- `auditoria-....html` / `auditoria-....json` guardam o relatório da auditoria. Não entram no Git.

## Licença

MIT. O texto completo está no arquivo `LICENSE`.
