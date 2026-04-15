import re
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np

log_dir = Path("Comb_Plotter/rpn_logs")

pattern_rpn = re.compile(r"OpenMP threads per rank:?\s+(\d+)")
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

rpn = []
times_std = []
times_pers = []
times_part = []

for logfile in sorted(log_dir.glob("*.txt")):
    text = logfile.read_text()

    m_rpn = pattern_rpn.search(text)
    if not m_rpn:
        continue

    m_std = block_std.search(text)
    m_pers = block_pers.search(text)
    m_part = block_part.search(text)
    if not (m_std and m_pers and m_part):
        continue

    rpn.append(int(m_rpn.group(1)))
    times_std.append(float(m_std.group(2)))
    times_pers.append(float(m_pers.group(2)))
    times_part.append(float(m_part.group(2)))

rpn_arr  = np.array(rpn, dtype=float)
std_arr  = np.array(times_std)
pers_arr = np.array(times_pers)
part_arr = np.array(times_part)

print("ranks_per_node:", rpn_arr)
print("std           :", std_arr)
print("persistent    :", pers_arr)
print("partitioned   :", part_arr)




# Speedup [%] = (T_std / T_opt - 1) / T_std * 100
speedup_pers = (std_arr / pers_arr - 1 ) * 100.0
speedup_part = (std_arr / part_arr - 1) * 100.0

print("speedup persistent [%]:", speedup_pers)
print("speedup partitioned [%]:", speedup_part)


plt.figure()

all_powers = [64, 32, 16, 8, 4, 2, 1]
xticks = [v for v in all_powers if v in rpn_arr]
plt.xscale("log", base=2)
plt.gca().invert_xaxis()
plt.xticks(xticks, [str(x) for x in xticks])


plt.axhline(0.0, color="k", linewidth=0.8, linestyle="--",
            label="Non-Blocking Baseline= 0 %")

plt.plot(
    rpn_arr, speedup_pers,
    marker="s", markersize=4, linewidth=2,
    color="tab:orange", label="Persistent vs. Non-Blocking",
)
plt.plot(
    rpn_arr, speedup_part,
    marker="^", markersize=4, linewidth=2,
    color="tab:green", label="Partitioned vs. Non-Blocking",
)

plt.xlabel("Threads pro Prozess")
plt.ylabel("Speedup gegenüber Non-Blocking [%]")
# plt.title("Threads per Process Scaling: Speedup (prozentuale Ersparnis)")

plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()

plt.savefig("rpn_scaling_speedup_bench_comm.png", dpi=200)
# plt.show()
