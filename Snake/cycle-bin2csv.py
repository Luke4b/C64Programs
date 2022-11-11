
# extracts the cycle from the snapshot and saves as a csv
# also checks for duplicate values

filename = 'goodloop'
input_file = "/home/luke/C64Programs/Snake/" + filename + ".bin"
output_file = "/home/luke/C64Programs/Snake/" + filename + ".csv"

f = open(input_file, 'rb') # opening a binary file
csv = open(output_file, 'w')
content = f.read() # reading all lines

def hex_format(i):
    return "{0:0{1}x}".format(i,2)

#  $3800-$3fff hamiltonian cycle
#  $1100-$1cff path data

length = 0x400
start = 0x00


lsb_start = start
lsb_end = lsb_start + length - 1
msb_start = lsb_start + length
msb_end = msb_start + length - 1

lsb = content[lsb_start:lsb_end]
msb = content[msb_start:msb_end]

words = []

# combine the lsb and msb into a 16bit number:
for index in range(length -1):
    words.append(hex_format(msb[index]) + hex_format(lsb[index]))

# check for duplicates
newlist = []
duplist = []

for i in words:
    if i not in newlist:
        newlist.append(i)
    else:
        duplist.append(i)

print(duplist)

for count, word in enumerate(words):
    csv.write(word + ',')
    if not (count + 1) % 40:
        csv.write('\n')

f.close
csv.close