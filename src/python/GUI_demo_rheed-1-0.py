#---------------------------------------------------------------
# GUI program for RHEED FPGA 
#---------------------------------------------------------------
# Initial RHEED FPGA has 10 (NUM_REGS) 32-bit r/w parameter registers, 
# a read-only version number register and a r/w LED control reg.
#
# Assuming that each 32-bit register contains a 5 pairs of 16-bit X,Y
# co-ordinates for either the upper left of a block of pixels
# bits 31:16  x-coord
# bits 15:0   y-coord
#---------------------------------------------------------------

from tkinter import *
#from tkinter import Tk, Canvas
import serial
import serial.tools.list_ports

#---------------------------------------------------------------
#---------------------------------------------------------------
# Configuration
NUM_REGS     = 5

# FPGA register addresses
ADDR_REG_PARAM0     = 0x0000
ADDR_REG_PARAM5     = 0x0004
ADDR_REG_VERSION    = 0x0008
ADDR_REG_LED        = 0x0009
dataGpo             = 0x55555555

#---------------------------------------------------------------
# Create the root dialog
#---------------------------------------------------------------
root = Tk()
root.title('GUI_demo_RHEED 1.1')
#root.geometry("300x350")    # Set the size of the app 
root.resizable(0, 0)        # Don't allow resizing in the x or y direction

strMsg              = StringVar()
strMsg1             = StringVar()

strAddrRegVersion   = StringVar()
strAddrRegVersion.set(str(hex(ADDR_REG_VERSION)))
strVersion          = StringVar()
print (strAddrRegVersion.get())
strVersion.set("- -") 


#---------------------------------------------------------------
# Initialize the X,Y co-ordinates in the entry boxes
#---------------------------------------------------------------
listX = [] 
listY = [] 
for i in range(NUM_REGS):  
    listX.append(StringVar())
    listX[i].set(i*100)
    listY.append(StringVar())
    listY[i].set(i*100)
    

#---------------------------------------------------------------
# Function to send a single byte to COM port
#---------------------------------------------------------------
def gj_send(ser, byte):
    print ('Send {}' .format(byte))
    ser.write(byte)

#---------------------------------------------------------------
# Function to read an entire line from the receive COM port
#---------------------------------------------------------------
def gj_recvline(ser):
    line = ser.readline()
    print ('{}' .format(line))
    

#---------------------------------------------------------------
# Read a register from the FPGA.
#---------------------------------------------------------------
# Convert address into a byte array.
# Send a read command sequence ('R' address16 data32)
#---------------------------------------------------------------
def gj_reg_read(ser, strRegAddr):
    regaddr     = 0
    regaddr = int(strRegAddr.get(), base = 16)
    wdata   = 0xFFFFFFFE # dummy data to get the correct message length
    print ('Read regaddr    = 0x{:04x}' .format(regaddr))
    print ('Write data      = 0x{:08x}' .format(wdata))
    strMsg = regaddr.to_bytes(2, byteorder='big') + wdata.to_bytes(4, byteorder='big')

    ser.write(b'\x52')
    ser.write(strMsg)

    # Read 5 characters from serial port ('A' and  4 bytes for data32)
    rdata = ser.read(5)

    # Convert 32-bit data into a hex string, print it and set it into the GUI entry box
    str_rdata = str(rdata[1:].hex())
    rvalue = int(str_rdata, 16)
    str_rdata = '0x' + str_rdata.upper()
    print ('Read data     = ' + str_rdata)
    return rvalue


#---------------------------------------------------------------
# Read version register from FPGA and set value in Entry box
#---------------------------------------------------------------
def read_version(ser):
    rvalue = gj_reg_read(ser, strAddrRegVersion)
    str_rdata = hex(rvalue)
    strVersion.set(str_rdata) 


#---------------------------------------------------------------
# Write 32-bit data to a 16-bit register address in the FPGA.
# Convert address and data strings into byte arrays.
# Send a write command sequence (W address16 data32)
#---------------------------------------------------------------
def gj_reg_write(ser, strRegAddr, strRegData):
    
    regaddr     = 0
    wdata       = 0

    regaddr = int(strRegAddr.get(), base = 16)
    wdata   = int(strRegData.get(), base = 16)

    print ('Write regaddr   = 0x{:04x}' .format(regaddr))
    print ('Write data      = 0x{:08x}' .format(wdata))

    strMsg = regaddr.to_bytes(2, byteorder='big') + wdata.to_bytes(4, byteorder='big')
    ser.write(b'\x57')
    ser.write(strMsg)
     

#---------------------------------------------------------------
# Write 32-bit data to a 16-bit register address in the FPGA.
# Convert address and data into byte arrays.
# Send a write command sequence (W address16 data32)
#---------------------------------------------------------------
def gj_reg_write_int(ser, regaddress, wdata):
    
    print ('Write regaddress = 0x{:04x}' .format(regaddress))
    print ('Write data       = 0x{:08x}' .format(wdata))
    strMsg = regaddress.to_bytes(2, byteorder='big') + wdata.to_bytes(4, byteorder='big')
    ser.write(b'\x57')
    ser.write(strMsg)


#---------------------------------------------------------------
# Combines an X and Y value into a 32-bit value to be written 
# to an FPGA register
#---------------------------------------------------------------
def set_xy(ser, index):

    # Combine X and Y values into a 32-bit value
   #pt_x = int(.get(), base = 16)
    wdata = (2**16) * int(listX[index].get()) + int(listY[index].get())
    
    # Convert the XY co-ord index into an FPGA address
    regaddress = index

    # Write to the FPGA
    gj_reg_write_int(ser, regaddress, wdata)


#---------------------------------------------------------------
# Set all registers to values in Entry boxes
#---------------------------------------------------------------
def set_all_xy():
    for i in range(NUM_REGS):
        set_xy(ser, i)


#---------------------------------------------------------------
# END OF FUNCTION DEFINITIONS
#---------------------------------------------------------------

#---------------------------------------------------------------
# Get a list of serial ports. Open first COM port.
#---------------------------------------------------------------
comlist = (list(serial.tools.list_ports.comports()))
print('Number of ports = {0:8}' .format(len(comlist)))


if len(comlist) > 0:
    portinfo = comlist[0]
    portname = portinfo[0]
    print(portname)

     # Open serial port
    ser = serial.Serial(
        port = "COM9",\
        baudrate=115200,\
        parity=serial.PARITY_NONE,\
        stopbits=serial.STOPBITS_ONE,\
        bytesize=serial.EIGHTBITS,\
        timeout=1)

    strMsg.set(ser.name)
    strMsg1.set(comlist[0][0])
    print (ser.name)
    print (comlist[0][0])

else:
    print("No ports")
    strMsg.set("None")
    strMsg1.set("0")


#---------------------------------------------------------------
# Build GUI
# Two columns of NUM_REGS entry boxes each. 
# One col has the header 'X' and the other is 'Y'
#---------------------------------------------------------------
frameSerialPorts = Frame(root, padx = 1, pady = 1)
Label (frameSerialPorts, text = 'Serial Ports').pack(side = LEFT, padx = 5, pady = 1)
Entry (frameSerialPorts, width = 10, textvariable = strMsg1).pack(side=RIGHT, padx = 5, pady = 1)
frameSerialPorts.pack(side=TOP, padx = 10, pady = 1)

#-----------------------------------------------------------------------------------------------------------------------------
# Read FPGA version
#-----------------------------------------------------------------------------------------------------------------------------
frameVersion   = Frame(root, borderwidth=3,relief=FLAT, padx = 5, pady = 2)
Label (frameVersion, text = 'Version ').pack(side = LEFT, padx = 5, pady = 2)
Entry (frameVersion, width = 12, textvariable = strVersion).pack(side=LEFT, padx = 5, pady = 2)
buttonVerRead  = Button (frameVersion, width = 10, text = "Read",  command = lambda: read_version(ser), state=DISABLED)
buttonVerRead.pack(side=LEFT)
frameVersion.pack(side=TOP, padx = 5, pady = 2)


#-----------------------------------------------------------------------------------------------------------------------------
# Frame for Registers  0 to NUM_REGS-1.  
#-----------------------------------------------------------------------------------------------------------------------------
arrFrameCh      = []
frameParamTop       = Frame(root, borderwidth=3, padx = 5, pady = 0)
frameParamHeader    = Frame(frameParamTop, borderwidth=1, padx = 5, pady = 0)
Label (frameParamHeader, text = 'Box         X               Y     ').pack(side = LEFT, padx = 5, pady = 2)
frameParamHeader.pack(side=TOP, padx = 5, pady = 0)

frameRegs = Frame(frameParamTop, borderwidth=1,relief=GROOVE, padx = 2, pady = 2)
for i in range(NUM_REGS):   # 
    arrFrameCh.append(Frame(frameRegs, borderwidth=1, padx = 2, pady = 1))
    Label (arrFrameCh[i], text = ('box ' + str(i))).pack(side = LEFT, padx = 2, pady = 1)
    Entry (arrFrameCh[i], width = 8, textvariable = listX[i]).pack(side=LEFT, padx = 2, pady = 1)
    Entry (arrFrameCh[i], width = 8, textvariable = listY[i]).pack(side=LEFT, padx = 2, pady = 1)
    arrFrameCh[i].pack(side=TOP, padx = 2, pady = 1)

frameRegs.pack(side=TOP, padx = 5, pady = 0)
frameParamTop.pack(side=TOP, padx = 5, pady = 0)

# Add a button to download all parameter registers 
frameSetXY      = Frame(root, borderwidth=3, relief=FLAT, padx = 5, pady = 2)
buttonSetXY     = Button (frameSetXY, width = 10, text = "Download",  command = lambda: set_all_xy(), state=DISABLED)
buttonSetXY.pack(side=LEFT,  padx = 5, pady = 5)
frameSetXY.pack(side=TOP, padx = 5, pady = 1)


frameQuitHelp   = Frame(root, borderwidth=3,relief=FLAT, padx = 2, pady = 2)
buttonQuit      = Button (frameQuitHelp, width = 10, text = "Quit",        command = root.quit).pack(side=RIGHT, padx = 5, pady = 5)
frameQuitHelp.pack(side=TOP, padx = 1, pady = 1)

#-----------------------------------------------------------------------------------------------------------------------------
# Enable buttons if a COM port is present
#-----------------------------------------------------------------------------------------------------------------------------
if len(comlist) != 0:

    buttonSetXY.config(state=NORMAL)
    buttonVerRead.config(state=NORMAL)

mainloop()

