"""Organiza a raiz de Downloads e limpa Temp, dumps e Prefetch no Windows.

Só mexe em arquivo solto na raiz de Downloads. Pastas que você já criou ficam intactas.
Instalador antigo vai para Instaladores; nada é desinstalado sozinho.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

PASTA_LIXO = "_Lixo"


def diretorio_app() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


ARQUIVO_CONFIG = diretorio_app() / "config.json"
ARQUIVO_LOG = diretorio_app() / "limpador.log"


def carregar_config() -> dict:
    with ARQUIVO_CONFIG.open(encoding="utf-8") as arquivo:
        return json.load(arquivo)


def configurar_log() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            logging.FileHandler(ARQUIVO_LOG, encoding="utf-8"),
            logging.StreamHandler(sys.stdout),
        ],
    )


def pasta_downloads(override: str | None) -> Path:
    if override:
        return Path(override).expanduser()
    return Path.home() / "Downloads"


def mapa_extensoes(config: dict) -> dict[str, str]:
    mapa: dict[str, str] = {}
    for pasta, extensoes in config["pastas"].items():
        for extensao in extensoes:
            mapa[extensao.lower()] = pasta
    return mapa


def arquivo_oculto_ou_sistema(caminho: Path) -> bool:
    if caminho.name.startswith("."):
        return True
    atributos = caminho.stat().st_file_attributes if os.name == "nt" else 0
    return bool(atributos & 0x6)  # HIDDEN | SYSTEM


def antigo_o_bastante(caminho: Path, dias: int, agora: datetime) -> bool:
    modificado = datetime.fromtimestamp(caminho.stat().st_mtime)
    return modificado <= agora - timedelta(days=dias)


def formatar_mb(nbytes: int) -> str:
    return f"{nbytes / (1024 * 1024):.1f} MB"


def tamanho(caminho: Path) -> int | None:
    try:
        return caminho.stat().st_size
    except OSError:
        return None


def destino_livre(pasta: Path, nome: str) -> Path:
    candidato = pasta / nome
    if not candidato.exists():
        return candidato
    base = Path(nome).stem
    sufixo = Path(nome).suffix
    indice = 1
    while True:
        candidato = pasta / f"{base} ({indice}){sufixo}"
        if not candidato.exists():
            return candidato
        indice += 1


def mover(origem: Path, destino: Path, simular: bool) -> None:
    logging.info("%s %s -> %s", "SIMULAR" if simular else "MOVER", origem.name, destino.parent.name)
    if simular:
        return
    destino.parent.mkdir(parents=True, exist_ok=True)
    origem.replace(destino_livre(destino.parent, destino.name))


def esvaziar_lixo(pasta: Path, dias: int, agora: datetime, simular: bool) -> tuple[int, int]:
    if not pasta.exists():
        return 0, 0
    apagados = 0
    liberados = 0
    for item in pasta.iterdir():
        if not item.is_file() or not antigo_o_bastante(item, dias, agora):
            continue
        peso = tamanho(item)
        if peso is None:
            continue
        logging.info("%s lixo %s", "SIMULAR apagar" if simular else "APAGAR", item.name)
        if not simular:
            try:
                item.unlink()
            except OSError as erro:
                logging.warning("Não deu para apagar %s: %s", item.name, erro)
                continue
        apagados += 1
        liberados += peso
    return apagados, liberados


def varrer(config: dict, simular: bool, raiz: Path) -> int:
    if not raiz.is_dir():
        logging.error("Pasta de Downloads não encontrada: %s", raiz)
        return 0

    agora = datetime.now()
    idade = int(config["idade_minima_dias"])
    mapa = mapa_extensoes(config)
    lixo = {ext.lower() for ext in config["lixo"]}
    movidos = 0
    quarentena = 0
    ignorados = 0

    for item in raiz.iterdir():
        if not item.is_file() or arquivo_oculto_ou_sistema(item):
            continue
        if not antigo_o_bastante(item, idade, agora):
            ignorados += 1
            continue

        extensao = item.suffix.lower()
        try:
            if extensao in lixo:
                mover(item, raiz / PASTA_LIXO / item.name, simular)
                quarentena += 1
            elif extensao in mapa:
                mover(item, raiz / mapa[extensao] / item.name, simular)
                movidos += 1
            else:
                ignorados += 1
        except OSError as erro:
            logging.warning("Não deu para mover %s: %s", item.name, erro)

    apagados, liberados = esvaziar_lixo(
        raiz / PASTA_LIXO,
        int(config["apagar_lixo_apos_dias"]),
        agora,
        simular,
    )
    logging.info(
        "Downloads. organizados=%s quarentena=%s apagados=%s recentes_ou_desconhecidos=%s",
        movidos,
        quarentena,
        apagados,
        ignorados,
    )
    return liberados


def eh_atalho(caminho: Path) -> bool:
    try:
        if caminho.is_symlink():
            return True
        atributos = caminho.lstat().st_file_attributes if os.name == "nt" else 0
        return bool(atributos & 0x400)
    except OSError:
        return True


def limpar_arvore(raiz: Path, dias: int, agora: datetime, simular: bool, extensoes: set[str] | None = None) -> tuple[int, int]:
    if not raiz.is_dir():
        logging.warning("Pasta não encontrada: %s", raiz)
        return 0, 0

    apagados = 0
    bloqueados = 0
    liberados = 0
    negado = False

    def sem_acesso(erro: OSError) -> None:
        nonlocal negado
        negado = True
        logging.warning("Sem acesso a %s: %s", getattr(erro, "filename", raiz), erro.strerror)

    try:
        caminhada = os.walk(raiz, followlinks=False, onerror=sem_acesso)
    except OSError as erro:
        logging.warning("Sem acesso a %s: %s", raiz, erro)
        return 0, 0

    for dirpath, dirnames, arquivos in caminhada:
        pasta = Path(dirpath)
        dirnames[:] = [nome for nome in dirnames if not eh_atalho(pasta / nome)]
        for nome in arquivos:
            item = pasta / nome
            if eh_atalho(item):
                continue
            if extensoes is not None and item.suffix.lower() not in extensoes:
                continue
            peso = tamanho(item)
            if peso is None:
                bloqueados += 1
                continue
            try:
                if not antigo_o_bastante(item, dias, agora):
                    continue
            except OSError:
                bloqueados += 1
                continue
            if not simular:
                try:
                    item.unlink()
                except OSError:
                    bloqueados += 1
                    continue
            apagados += 1
            liberados += peso

    if not simular:
        for dirpath, _, _ in os.walk(raiz, topdown=False, followlinks=False):
            pasta = Path(dirpath)
            if pasta == raiz or eh_atalho(pasta):
                continue
            try:
                if any(pasta.iterdir()):
                    continue
                pasta.rmdir()
            except OSError:
                pass

    if negado and apagados == 0:
        return 0, 0

    logging.info(
        "%s apagados=%s em_uso=%s liberados=%s em %s",
        "SIMULAR" if simular else "LIMPAR",
        apagados,
        bloqueados,
        formatar_mb(liberados),
        raiz,
    )
    return apagados, liberados


def limpar_pasta_configurada(bloco: dict, pasta: Path, agora: datetime, simular: bool, idade_padrao: int) -> int:
    if not bloco.get("ligado", True) or not pasta.is_dir():
        return 0
    _, liberados = limpar_arvore(pasta, int(bloco.get("idade_minima_dias", idade_padrao)), agora, simular)
    return liberados


def limpar_sistema(config: dict, simular: bool, incluir_prefetch: bool) -> int:
    agora = datetime.now()
    liberados = 0
    temp = config.get("temp", {})
    if temp.get("ligado", True):
        vistas: set[Path] = set()
        for chave in ("TEMP", "TMP"):
            valor = os.environ.get(chave)
            if not valor:
                continue
            pasta = Path(valor).resolve()
            if pasta in vistas:
                continue
            vistas.add(pasta)
            _, parte = limpar_arvore(pasta, int(temp.get("idade_minima_dias", 1)), agora, simular)
            liberados += parte

    sistema = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    liberados += limpar_pasta_configurada(config.get("windows_temp", {}), sistema / "Temp", agora, simular, 1)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        liberados += limpar_pasta_configurada(
            config.get("crashdumps", {}),
            Path(local) / "CrashDumps",
            agora,
            simular,
            1,
        )

    prefetch = config.get("prefetch", {})
    if incluir_prefetch and prefetch.get("ligado", True):
        pasta = sistema / "Prefetch"
        try:
            next(pasta.iterdir(), None)
        except OSError:
            logging.warning("Prefetch sem permissão. Abra o limpador como administrador para limpar %s", pasta)
            return liberados
        antes = sum(1 for item in pasta.glob("*.pf") if item.is_file())
        _, parte = limpar_arvore(pasta, int(prefetch.get("idade_minima_dias", 0)), agora, simular, {".pf"})
        liberados += parte
        if not simular:
            restantes = sum(1 for item in pasta.glob("*.pf") if item.is_file())
            logging.info("Prefetch antes=%s restantes=%s", antes, restantes)
            if restantes:
                logging.info("O Windows recria .pf sozinho quando um programa abre. Por isso a pasta não fica vazia.")
    return liberados


def aberto_por_clique() -> bool:
    if os.name != "nt" or not getattr(sys, "frozen", False):
        return False
    import ctypes

    processos = (ctypes.c_uint * 2)()
    quantidade = ctypes.windll.kernel32.GetConsoleProcessList(processos, 2)
    return quantidade == 1


def analisar_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Organiza arquivos antigos da pasta Downloads.")
    modo = parser.add_mutually_exclusive_group()
    modo.add_argument("--aplicar", action="store_true", help="Move e apaga de verdade.")
    modo.add_argument("--simular", action="store_true", help="Só mostra o que faria, sem mover nada.")
    modo.add_argument("--vigiar", action="store_true", help="Fica em segundo plano e repete a limpeza.")
    parser.add_argument("--pasta", help="Usa outra pasta no lugar de Downloads. Útil para testar.")
    return parser.parse_args()


def main() -> None:
    configurar_log()
    args = analisar_args()
    config = carregar_config()
    executavel = bool(getattr(sys, "frozen", False))
    simular = args.simular or not (args.aplicar or args.vigiar or executavel)

    if simular:
        logging.info("Simulação. Nada será movido. Use --aplicar para valer.")

    raiz = pasta_downloads(args.pasta)
    incluir_prefetch = not args.vigiar
    liberados = varrer(config, simular, raiz)
    if args.pasta is None:
        liberados += limpar_sistema(config, simular, incluir_prefetch)
    logging.info("%sTotal liberado %s", "SIMULAR " if simular else "", formatar_mb(liberados))
    if not args.vigiar:
        return

    intervalo = max(1, int(config["intervalo_minutos"])) * 60
    logging.info("Vigia ativa. Prefetch fica de fora. Próxima passagem em %s min.", intervalo // 60)
    while True:
        time.sleep(intervalo)
        try:
            config = carregar_config()
            liberados = varrer(config, False, raiz)
            if args.pasta is None:
                liberados += limpar_sistema(config, False, incluir_prefetch=False)
            logging.info("Total liberado %s", formatar_mb(liberados))
        except Exception:
            logging.exception("Falha na passagem agendada")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logging.exception("O limpador parou com erro")
    if aberto_por_clique():
        input("\nEnter para fechar...")
