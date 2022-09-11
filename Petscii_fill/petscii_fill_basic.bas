05 B = 0
10 for x = 0 to 999
20 poke 55296 + x, a
30 poke 1024 + x, b
40 a = a + 1
50 if a = 16 then a = 0
60 next x
65 b = b+1
66 if b = 226 then b = 0
70 goto 10