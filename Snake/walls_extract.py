
# extracts the cycle from the ramdump within vice snapshot and saves as a binary file
filename = 'cycle'
input_file = "F:\\c64code\\C64Programs\\Snake\\troubleshoot\\" + filename + ".vsf"
column_output_file = "F:\\c64code\\C64Programs\\Snake\\troubleshoot\\" + filename + "_column_walls.bin"
row_output_file = "F:\\c64code\\C64Programs\\Snake\\troubleshoot\\" + filename + "_row_walls.bin"

f = open(input_file, 'rb') # opening a binary file
row_bin = open(row_output_file, 'wb')
column_bin = open(column_output_file, 'wb')
content = f.read() # reading all lines

#  $1d00-$1dff column_walls
#  $1e00-$1eff row_walls


offset = 0xc5   # start of ram dump within snapshot file
length = 0x100
start = 0x1c00

cols_start = start + offset
cols_end = cols_start + length
rows_start = cols_start + length + 1
rows_end = rows_start + length


columns = content[cols_start:cols_end]
rows = content[rows_start:rows_end]

column_bin.write(columns)
row_bin.write(rows)

f.close
row_bin.close
column_bin.close