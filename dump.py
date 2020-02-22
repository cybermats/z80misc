
content = [ i for x in range(128) for i in ([x] + ([0]*15))]
data = bytearray(content)
print(data)
newFile = open("check.bin", "wb")
newFile.write(data)
newFile.close()