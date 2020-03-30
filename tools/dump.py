
content = [ i for x in range(128) for i in ([x])]
data = bytearray(content)
print(data)
newFile = open("check.bin", "wb")
newFile.write(data)
newFile.close()
