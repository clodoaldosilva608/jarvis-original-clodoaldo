r"""Diagnostico de arranque — mostra exatamente onde o Mark LIV para.

Rode com o python do .venv:
    .\.venv\Scripts\python.exe -u diagnostico.py

Cada passo imprime na hora. O ultimo passo impresso antes do silencio
e onde esta o problema. Se algo travar por 120s, o faulthandler despeja
as pilhas de todas as threads e sai.
"""
import faulthandler
import importlib
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
faulthandler.dump_traceback_later(120, exit=True)

T0 = time.time()


def stamp(msg: str) -> None:
    print(f"[{time.time() - T0:6.1f}s] {msg}", flush=True)


stamp("python " + sys.version.split()[0] + f"  ({sys.executable})")
stamp("importando PyQt6...")
import PyQt6.QtWidgets  # noqa: E402

stamp("PyQt6 OK")
stamp("importando numpy...")
import numpy  # noqa: E402

stamp("numpy OK")
stamp("importando opencv (cv2)...")
import cv2  # noqa: E402

stamp("cv2 OK")
stamp("importando sounddevice (audio/PortAudio)...")
import sounddevice  # noqa: E402

stamp("sounddevice OK")
stamp("importando google-genai...")
from google import genai  # noqa: E402

stamp("google-genai OK")
stamp("importando ui.py (janela, avatar)...")
import ui  # noqa: E402

stamp("ui.py OK")

for f in sorted((HERE / "actions").glob("*.py")):
    if f.stem.startswith("_"):
        continue
    stamp("importando actions/" + f.stem + "...")
    importlib.import_module("actions." + f.stem)
    stamp("actions/" + f.stem + " OK")

for f in sorted((HERE / "core").glob("*.py")):
    if f.stem.startswith("_"):
        continue
    stamp("importando core/" + f.stem + "...")
    importlib.import_module("core." + f.stem)
    stamp("core/" + f.stem + " OK")

stamp("importando memory...")
import memory.memory_manager  # noqa: E402

stamp("memory OK")

stamp("=" * 60)
stamp("TODOS OS IMPORTS PASSARAM.")
stamp("Se chegou aqui, o travamento (se existir) esta na")
stamp("inicializacao da janela/sessao — rode o teste com watchdog:")
stamp(r'  .\.venv\Scripts\python.exe -u -c "import faulthandler,runpy; faulthandler.dump_traceback_later(75, exit=True); runpy.run_path(''main.py'', run_name=''__main__'')"')
stamp("=" * 60)
