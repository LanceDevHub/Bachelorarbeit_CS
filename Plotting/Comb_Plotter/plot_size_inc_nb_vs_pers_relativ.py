import re
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = Path(__file__).resolve().parent
log_dir = BASE_DIR / "nb_vs_pers"


re_nb = re.compile(r"Non-blocking.*?avg = ([0-9.eE+-]+)", re.S)
re_pers = re.compile(r"Persistent.*?avg = ([0-9.eE+-]+)", re.S)

files = sorted(log_dir.glob("*.out"))
sizes_kiB = np.array([6,   24,  96,  384, 1536, 6144], dtype=float)

nb_avg, pers_avg = [], []
for f, size_kb in zip(files, sizes_kiB):
    text = f.read_text(encoding="utf-8", errors="ignore")
    if (m_nb := re_nb.search(text)) and (m_p := re_pers.search(text)):
        nb_avg.append(float(m_nb.group(1)))
        pers_avg.append(float(m_p.group(1)))

sizes_arr = sizes_kiB[:len(nb_avg)]
nb_arr = np.array(nb_avg)
pers_arr = np.array(pers_avg)
speedup_pers = (nb_arr / pers_arr - 1) * 100

print("KiB:", sizes_arr)
print("NB [s]:", nb_arr)
print("Pers [s]:", pers_arr)
print("Speedup [%]:", speedup_pers)


plt.figure(figsize=(8,5))
plt.plot(sizes_arr, speedup_pers, 's-', color='tab:orange', markersize=7, linewidth=3, label="Persistent")
plt.axhline(0.0, color="k", ls='--', label="Non-blocking (0%)")
plt.xscale('log', base=4)
plt.xticks(sizes_arr, [f"{int(s)}" for s in sizes_arr], rotation=45)
plt.xlabel("Nachrichtengröße [KiB]")
plt.ylabel("Speedup [%]")
plt.grid(True, alpha=0.6)
plt.legend()
plt.tight_layout()
plt.savefig(BASE_DIR / "speedup.png", dpi=300, bbox_inches='tight')
plt.show()
