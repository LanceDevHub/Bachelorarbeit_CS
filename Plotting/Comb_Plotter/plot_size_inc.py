import re
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np

log_dir = Path("Comb_Plotter/size_logs")  

pattern_size = re.compile(r"Message size:\s+(\d+)")  
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

sizes = [256 * 3 * 8 / 1024, 1024 * 3 * 8 / 1024, 4096 * 3 * 8 / 1024, 16384 * 3 * 8 / 1024, 65536 * 3 * 8 / 1024]

times_std = []
times_pers = []
times_part = []

for logfile in sorted(log_dir.glob("*.txt")):
    text = logfile.read_text()

    m_std = block_std.search(text)
    m_pers = block_pers.search(text)
    m_part = block_part.search(text)

    if not (m_std and m_pers and m_part):
        continue

    times_std.append(float(m_std.group(2)))
    times_pers.append(float(m_pers.group(2)))
    times_part.append(float(m_part.group(2)))

sizes_arr = np.array(sizes[:len(times_std)], dtype=float)
std_arr   = np.array(times_std)
pers_arr  = np.array(times_pers)
part_arr  = np.array(times_part)

print("sizes      :", sizes_arr)
print("std        :", std_arr)
print("persistent :", pers_arr)
print("partitioned:", part_arr)

plt.figure()

plt.plot(
    sizes_arr, std_arr,
    marker="o", markersize=4, linewidth=2,
    color="tab:blue", label="Non-Blocking",
)
plt.plot(
    sizes_arr, pers_arr,
    marker="s", markersize=4, linewidth=2,
    color="tab:orange", label="Persistent",
)
plt.plot(
    sizes_arr, part_arr,
    marker="^", markersize=4, linewidth=2,
    color="tab:green", label="Partitioned",
)

plt.xscale("log", base=4)  # 256, 1024, 4096, 16384, 65536 
plt.xticks(sizes_arr, [str(int(s)) for s in sizes_arr])

plt.xlabel("Größe einer Halo-Fläche [KiB]")
plt.ylabel("Zeit [s]")
# plt.title("Size Increase Scaling")

plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()

plt.savefig("size_scaling_bench_comm.png", dpi=200)
# plt.show()
