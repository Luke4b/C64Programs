print("{0:0{1}x}".format(42,2))

#Explanation:

# {   # Format identifier
# 0:  # first parameter
# #   # use "0x" prefix
# 0   # fill with zeroes
# {1} # to a length of n characters (including 0x), defined by the second parameter
# x   # hexadecimal number, using lowercase letters for a-f
# }   # End of format identifier