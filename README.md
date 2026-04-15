# README Bachelorarbeit  MPI-Kommunikationsmuster

Dieses Repository enthält alle im Rahmen meiner Bachelorarbeit (Leonard Emter) verwendeten Codes, Benchmarks und Auswerteskripte zur Untersuchung verschiedener MPI-Kommunikationsmuster (non-blocking, persistent, partitioned).

---

## Ordnerübersicht

### BApdf
In BApdf liegt die finale Fassung der Bachelorarbeit als PDF.

### comb
Im Ordner comb befindet sich der COMB-Benchmark mit den für die Arbeit relevanten MPI-Varianten, den Slurm-Skripten und den erzeugten Ergebnisdateien.

### halo-bench
Im Ordner halo-bench liegt eine isolierte Umgebung für einen MPI-Ring-Benchmark, in der insbesondere non-blocking und persistent Kommunikation verglichen werden.

### rdtsc-test
Im Ordner rdtsc-test liegt ein kleiner, selbst erstellter Benchmark zur konzeptionellen Darstellung eines Kontrollflusses, der CPU-Zyklen mit RDTSC misst.

### Plotting
Im Ordner Plotting befinden sich alle Python-Skripte, die zur Auswertung und Visualisierung der Messdaten der Bachelorarbeit verwendet wurden.

---

# How to: Benchmarks ausführen

---

# 1. COMB-Benchmark (Ordner comb)

## 1.1 Build auf Mogon

Zum Bauen des COMB-Benchmarks für die MPI-Experimente in den Ordner "comb" wechseln und das Setup-Skript ausführen.

Wechsel in den Ordner comb:

```
cd comb
```

Das Skript setup_mpi_mogon.sh ausführen:

```
./setup_mpi_mogon.sh
```

---

## 1.2 Ausführung der Benchmarks

Zur Ausführung der Benchmarks auf Mogon in den Unterordner run_mpi innerhalb von comb wechseln und den Slurm-Job einreichen.

Wechsel in den Ordner comb/run_mpi:

```
cd comb/run_mpi
```

Einreichen des Slurm-Jobs mit dem Befehl:

```
sbatch run_mogon_benchmarks.slurm
```

Das Slurm-Skript `run_mogon_benchmarks.slurm` ruft intern ein Testskript mit den gewünschten Parametern auf:

```
basic_persistent_partitioned_tests.bash
```

---

## 1.3 Bedeutung der wichtigsten Parameter in diesen Skripten

In der Datei `basic_persistent_partitioned_tests.bash` werden unter anderem folgende Parameter gesetzt.

### Gittergröße pro Prozess

```
elems_per_procs_x = 64
elems_per_procs_y = 64
elems_per_procs_z = 64
```

Diese drei Parameter beschreiben die lokale Gittergröße pro Prozess in x-, y- und z-Richtung.

### Iterationen

```
CYCLES = 10
```

Dies ist die Anzahl der Iterationen des Benchmarks.

### OpenMP Threads

```
THREADS = 2
```

Dies ist die Anzahl der OpenMP-Threads pro MPI-Prozess.  
Sollten hier Anpassungen vorgenommen werden, muss die partitioned policy bearbeitet werden und der Benchmark neu kompiliert werden.

### Variablen pro Gitterzelle

```
VARS = 3
```

Dies ist die Anzahl der Variablen pro Gitterzelle.

In der Datei `run_mogon_benchmarks.slurm` werden die Slurm-Ressourcen und das Prozess-Mapping festgelegt:

```
nodes = 2
ntasks = 64
ntasks-per-node = 32
cpus-per-task = 2
```

Außerdem wird dort das Skript `run_ba_tests.bash` mit der Option `ppn` und der dreidimensionalen Prozessaufteilung aufgerufen, zum Beispiel:

```
ppn 32 4 4 4
```

Dabei bedeutet:

- 32 Prozesse pro Node  
- 4 4 4 ist die Aufteilung dieser 32 Prozesse auf die Achsen x, y und z  

Es handelt sich also um ein dreidimensionales Prozessgitter mit **4 × 4 × 4 Prozessen**.

---

## 1.4 Ergebnisse des COMB-Benchmarks

Die Ergebnisse der COMB-Messungen, die auch in der Bachelorarbeit verwendet wurden, werden im Ordner

```
comb/run_mpi/results_mpi
```

abgelegt.

Neue Testläufe werden ebenfalls in diesem Ordner gespeichert und können von dort aus für weitere Auswertungen verwendet werden.

---

# 2. Halo-Benchmark (Ordner halo-bench)

Der MPI-Ring-Benchmark befindet sich im Unterordner `nb_vs_pers` des Ordners halo-bench:

```
halo-bench/nb_vs_pers
```

---

## 2.1 Ausführung

Zur Ausführung des Benchmarks in den Ordner halo-bench/nb_vs_pers wechseln und den Slurm-Job einreichen:

```
cd halo-bench/nb_vs_pers
sbatch halo_job.slurm
```

---

## 2.2 Parameter

Die relevanten Parameter des Benchmarks werden direkt in der Datei `halo_job.slurm` gesetzt.

Wichtige Beispiele sind:

### Anzahl der Zellen

```
cells 4096
```

Gibt die Anzahl der Zellen in der betrachteten Domäne an.

### Iterationen

```
iters 1000
```

Gibt die Anzahl der Iterationen an.

Diese Parameter können angepasst werden, um unterschiedliche Problemgrößen und Iterationen zu untersuchen.

---

## 2.3 Ergebnisse des Halo-Benchmarks

Die Ausgaben und Logdateien des Halo-Benchmarks werden im Ordner

```
halo-bench/nb_vs_pers/log
```

gespeichert.

---

# 3. RDTSC-Benchmark (Ordner rdtsc-test)

Im Ordner `rdtsc-test` befindet sich ein kleiner Benchmark, der die Messung von CPU-Zyklen mit Hilfe der **RDTSC-Instruktion** demonstriert. Dabei geht es vor allem um die konzeptionelle Darstellung des Kontrollflusses und der Messung, nicht um eine parametrisierbare Benchmark-Suite.

---

## 3.1 Ausführung

Zur Ausführung in den Ordner rdtsc-test wechseln und den Slurm-Job einreichen:

```
cd rdtsc-test
sbatch rdtsc_job.slurm
```

---

## 3.2 Parameter

In dieser Variante sind keine extern anzupassenden Parameter vorgesehen, da die Struktur des Kontrollflusses im Vordergrund steht und die CPU-Zyklen lediglich zur Veranschaulichung gemessen werden.

---


## 3.3 Ergebnisse des Halo-Benchmarks

Die Ausgaben und Logdateien des RDTSC-Benchmarks werden im Ordner

```
rdtsc-test/log
```

gespeichert.

---

# 4. Plotting-Skripte (Ordner Plotting)

Im Ordner `Plotting` liegen alle Python-Skripte, die zur Auswertung und Visualisierung der in der Bachelorarbeit verwendeten Messdaten genutzt wurden.