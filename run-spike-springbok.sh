#! /bin/bash
# Run spike simulation on springbok ELFs

if [[ -z "${ROOTDIR}" ]]; then
  echo "Source build/setup.sh first"
  exit 1
fi

if [[ ! -f "${OUT}/host/spike/bin/spike" ]]; then
  echo "run \`m -j64 spike\` first"
  exit 1
fi

if [[ "$#" -eq 0 || $1 == "--help" ]]; then
  echo "Usage: run-spike-springbok.sh <elf path>"
  exit 0
fi

# spike CLI options:
# -m<a:m,b:n>: specifies the memory layout. Springbok currently has 16MB TCM 
# at 0x3400_0000
# --varch: specifies the v-ext configuration w.r.t. vlen and elen.
# --pc: ELF entry point. Set at the beginning of IMEM.
"${OUT}/host/spike/bin/spike" -m0x34000000:0x1000000 \
 --varch=vlen:512,elen:32 --pc=0x34000000 $@
