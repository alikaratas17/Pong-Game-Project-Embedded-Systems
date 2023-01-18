import serial
import time
ser = serial.Serial('COM3',9600,timeout=1)
def getSlider():
    enc = ser.read()
    i=int.from_bytes(enc,'little')
    return (i & 0x0f)*4+4
def getY():
    enc = ser.read()
    i=int.from_bytes(enc,'little')
    return i & 0b111111
def goDown():
    ser.write(b'D')
def goUp():
    ser.write(b'U')
while 1:
    for i in range(2):
        s = getSlider()
        y = getY()
        if s > y:
            goUp()
            print("UP: {} > {}".format(s,y))
        if s < y:
            goDown()
            print("DOWN: {} < {}".format(s,y))
    time.sleep(0.001)

