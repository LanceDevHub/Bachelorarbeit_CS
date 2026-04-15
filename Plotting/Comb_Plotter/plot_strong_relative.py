import re
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np

log_dir = Path("Comb_Plotter/strong_logs")

pattern_ranks = re.compile(r"MPI ranks \(processes\):\s+(\d+)")

block_std = re.compile(
    r"Starting test Comm mpi Mesh.*?(^bench-comm\s*,\s*\d+\s*,\s*([0-9.]+))",
    re.M | re.S,
)
block_pers = re.compile(
    r"Starting test Comm mpi_persistent Mesh.*?(^bench-comm\s*,\s*\d+\s*,\s*([0-9.]+))",
    re.M | re.S,
)
block_part = re.compile(
    r"Starting test Comm mpi_partitioned Mesh.*?(^bench-comm\s*,\s*\d+\s*,\s*([0-9.]+))",
    re.M | re.S,
)

ranks = []
times_std = []
times_pers = []
times_part = []

for logfile in sorted(log_dir.glob("*.txt")):
    text = logfile.read_text()

    m_ranks = pattern_ranks.search(text)
    if not m_ranks:
        continue

    m_std = block_std.search(text)
    m_pers = block_pers.search(text)
    m_part = block_part.search(text)

    if not (m_std and m_pers and m_part):
        continue

    ranks.append(int(m_ranks.group(1)))
    times_std.append(float(m_std.group(2)))
    times_pers.append(float(m_pers.group(2)))
    times_part.append(float(m_part.group(2)))

print("ranks      :", ranks)
print("std        :", times_std)
print("persistent :", times_pers)
print("partitioned:", times_part)


ranks_arr = np.array(ranks, dtype=float)
std_arr   = np.array(times_std)
pers_arr  = np.array(times_pers)
part_arr  = np.array(times_part)


# Speedup [%] = (T_std / T_opt - 1) * 100
speedup_pers = (std_arr / pers_arr - 1 ) * 100.0
speedup_part = (std_arr / part_arr - 1 ) * 100.0

print("speedup persistent [%]:", speedup_pers)
print("speedup partitioned [%]:", speedup_part)


plt.figure()

xticks = sorted(set(ranks))
plt.xscale("log", base=2)
plt.xticks(xticks, [str(x) for x in xticks])

plt.axhline(0.0, color="k", linewidth=0.8, linestyle="--",
            label="Non-Blocking Baseline = 0 %")

plt.plot(
    ranks_arr, speedup_pers,
    marker="s", markersize=4, linewidth=2,
    color="tab:orange", label="Persistent vs. Non-Blocking",
)
plt.plot(
    ranks_arr, speedup_part,
    marker="^", markersize=4, linewidth=2,
    color="tab:green", label="Partitioned vs. Non-Blocking",
)

plt.xlabel("Anzahl Prozesse")
plt.ylabel("Speedup gegenüber Non-Blocking [%]")
# plt.title("Strong Scaling: Speedup (prozentuale Ersparnis)")

plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()

plt.savefig("strong_scaling_speedup_bench_comm.png", dpi=200)
# plt.show()
