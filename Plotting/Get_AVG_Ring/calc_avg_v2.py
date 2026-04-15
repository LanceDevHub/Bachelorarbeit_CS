import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"

out_name = sys.argv[1] if len(sys.argv) > 1 else "avg_combined.out"

if not DATA_DIR.is_dir():
    print(f"Fehler: Ordner {DATA_DIR} existiert nicht.")
    sys.exit(1)

files = sorted(DATA_DIR.glob("*.out"))
if len(files) < 5:
    print(f"Fehler: Weniger als 5 .out-Dateien in {DATA_DIR} gefunden.")
    sys.exit(1)

input_files = files[:5]
headers, all_data = [], []

for path in input_files:
    text = path.read_text()
    
    
    m_nb = re.search(r"Non-blocking \(Isend/Irecv\):\s*Total time \[s\]\s*:\s*min = ([0-9.eE+-]+)\s*avg = ([0-9.eE+-]+)\s*max = ([0-9.eE+-]+)", text, re.MULTILINE)
    if not m_nb: raise ValueError(f"NB nicht in {path}")
    nb_min, nb_avg, nb_max = [float(x) for x in m_nb.groups()]
    
    m_p = re.search(r"Persistent \(Send_init/Startall\):\s*Total time \[s\]\s*:\s*min = ([0-9.eE+-]+)\s*avg = ([0-9.eE+-]+)\s*max = ([0-9.eE+-]+)", text, re.MULTILINE)
    if not m_p: raise ValueError(f"Pers nicht in {path}")
    p_min, p_avg, p_max = [float(x) for x in m_p.groups()]
    
    m = re.search(r"Speedup \(based on AVG time\):\s*Speedup\s*:\s*([0-9.eE+-]+)", text)
    if not m: raise ValueError(f"Speedup nicht in {path}")
    speedup = float(m.group(1))
    
    all_data.append({"nb_min":nb_min, "nb_avg":nb_avg, "nb_max":nb_max,
                     "p_min":p_min, "p_avg":p_avg, "p_max":p_max, "speedup":speedup})
    
    
    if not headers:
        header = {}
        for k, pat in [("ranks", r"Ranks\s*:\s*([0-9]+)"), ("cells", r"Cells per message\s*:\s*([0-9]+)"),
                       ("vars", r"Variables per cell\s*:\s*([0-9]+)"), ("doubles", r"Doubles per message\s*:\s*([0-9]+)"),
                       ("bytes", r"Bytes per message\s*:\s*([0-9]+)"), ("iters", r"Iterations\s*:\s*([0-9]+)")]:
            m = re.search(pat, text)
            if m: header[k] = int(m.group(1))
        headers.append(header)

h0 = headers[0]
def avg(key): return sum(d[key] for d in all_data) / len(all_data)

nb_min, nb_avg, nb_max = avg("nb_min"), avg("nb_avg"), avg("nb_max")
p_min, p_avg, p_max = avg("p_min"), avg("p_avg"), avg("p_max")
speedup = avg("speedup")
message_kb = h0['bytes'] / 1024.0

out_text = f"""===== Halo Benchmark (1D Ring, 2 Neighbours, AVG over 5 runs) =====
# Nachrichtengroesse pro Message: {message_kb:.2f} kB

Ranks                 : {h0['ranks']}
Cells per message     : {h0['cells']}
Variables per cell    : {h0['vars']}
Doubles per message   : {h0['doubles']}
Bytes per message     : {h0['bytes']}
Iterations            : {h0['iters']}

Non-blocking (Isend/Irecv):
  Total time [s]      : min = {nb_min:.6e}  avg = {nb_avg:.6e}  max = {nb_max:.6e}

Persistent (Send_init/Startall):
  Total time [s]      : min = {p_min:.6e}  avg = {p_avg:.6e}  max = {p_max:.6e}

Speedup (based on AVG time):
  Speedup             : {speedup:.3f} x
"""

out_path = SCRIPT_DIR / out_name
out_path.write_text(out_text)
print(f"Ergebnis in {out_path} geschrieben.")