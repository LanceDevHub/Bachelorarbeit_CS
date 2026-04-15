#!/bin/bash

set -e  # Script bei Fehler beenden

# Module laden
module purge 
module load compiler/GCC/13.3.0
module load mpi/OpenMPI/5.0.3-GCC-13.3.0

# Prüft, ob das Skript im richtigen Verzeichnis gestartet wurde
if [ ! -f CMakeLists.txt ]; then
  echo "Error: CMakeLists.txt nicht gefunden. Skript bitte im Projekt-Hauptverzeichnis ausführen."
  exit 1
fi

# Build-Verzeichnis anlegen
mkdir -p build_mpi
cd build_mpi

# cmake-Befehl mit Fehlermeldung bei Fehlschlag
if ! cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=mpicxx -DENABLE_MPI=ON \
  -DENABLE_OPENMP=ON; then
  echo "Error: cmake-Konfiguration fehlgeschlagen."
  exit 2
fi

# make-Befehl mit parallelem Build
if ! make -j$(nproc); then
  echo "Error: Kompilierung fehlgeschlagen."
  exit 3
fi

cd ..

# Run-Verzeichnis anlegen
mkdir -p run_mpi
cd run_mpi

# Prüfen, ob Binary existiert
if [ ! -f ../build_mpi/bin/comb ]; then
  echo "Error: Binary ../build_mpi/bin/comb nicht gefunden."
  exit 4
fi

# Verlinken des Binaries
ln -sf ../build_mpi/bin/comb .

# Prüfen, ob Scripts existieren
if [ ! -d ../scripts ]; then
  echo "Warnung: Verzeichnis ../scripts nicht gefunden. Keine Skripte werden verlinkt."
else
  ln -sf ../scripts/* .
fi

echo "Setup abgeschlossen."
