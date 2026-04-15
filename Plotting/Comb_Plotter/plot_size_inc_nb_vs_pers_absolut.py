import re
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = Path(__file__).resolve().parent
log_dir = BASE_DIR / "nb_vs_pers"

re_nb = re.compile(r"Non-blocking \(Isend/Irecv\):.*?avg = ([0-9.eE+-]+)", re.S)
re_pers = re.compile(r"Persistent \(Send_init/Startall\):.*?avg = ([0-9.eE+-]+)", re.S)

# KiB pro Nachrichtengröße (cells * 3 vars * 8 Byte / 1024)
sizes_kb = np.array([6,   24,  96,  384, 1536, 6144], dtype=float)

nb_avg, pers_avg = [], []
cell_names = ["256", "1024", "4096", "16384", "65536", "262144"]

for i, (size_kb, cell_name) in enumerate(zip(sizes_kb, cell_names)):
    f = log_dir / f"{i+1}_{cell_name}.out"
    if not f.exists():
        print(f"Fehlt: {f}")
        continue
    
    text = f.read_text(encoding="utf-8", errors="ignore")
    if (m_nb := re_nb.search(text)) and (m_p := re_pers.search(text)):
        nb_avg.append(float(m_nb.group(1)))
        pers_avg.append(float(m_p.group(1)))
    else:
        print(f"Parse-Fehler: {f}")

sizes_arr = sizes_kb[:len(nb_avg)]
nb_arr = np.array(nb_avg)
pers_arr = np.array(pers_avg)

print("Größen [KiB]:", sizes_arr)
print("NB avg [s]:  ", nb_arr)
print("Pers avg [s]:", pers_arr)

plt.figure(figsize=(8,5))
plt.plot(sizes_arr, nb_arr, 'o-', label='Non-Blocking', color='tab:blue')
plt.plot(sizes_arr, pers_arr, 's-', label='Persistent', color='tab:orange')

plt.xscale('log', base=2)
plt.xticks(sizes_arr, [f"{int(s)}" for s in sizes_arr])
plt.xlabel("Nachrichtengröße [KiB]")
plt.ylabel('Zeit [s]')
plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig(BASE_DIR / "nb_vs_pers.png", dpi=200, bbox_inches='tight')
plt.show()
