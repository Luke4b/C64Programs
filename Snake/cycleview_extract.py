
# extracts the cycle from the ramdump within vice snapshot and saves as a binary file
filename = 'goodloop'
input_file = "F:\\c64code\\C64Programs\\" + filename + ".vsf"
output_file = "F:\\c64code\\C64Programs\\" + filename + ".bin"

f = open(input_file, 'rb') # opening a binary file
bin = open(output_file, 'wb')
content = f.read() # reading all lines

#  $3800-$3fff hamiltonian cycle

offset = 0xc5   # start of ram dump within snapshot file
length = 0x800
start = 0x3800

cycle_start = start + offset
cycle_end = cycle_start + length

cycle = content[cycle_start:cycle_end]

bin.write(cycle)

f.close
bin.close




