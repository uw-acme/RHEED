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
# Reads a .png file, scales it to fit in a canvas widget.
# User clicks on center of gaussian blobs. 
# A box is drawn on the image.
# Co-ordinates of upper left of the box are put into a FIFO list.
# List can be downloaded to FPGA. 

from    tkinter import *
from    PIL import ImageTk, Image

import  math 
import  serial
import  h5py
import  serial.tools.list_ports
import  numpy as np
import  argparse as ap
import  sys                 # for command line params
import  os.path

#---------------------------------------------------------------
# 1.1  : Add pny image import with boxes
# 1.2  : h5 and png image import. Arg parsing
#---------------------------------------------------------------
strScriptVersion = "GUI_demo_RHEED 1.2" 
fileNameh5       = 'not set'
fileNamePng      = 'not set'
#---------------------------------------------------------------
# Configuration
NUM_REGS     = 5

# FPGA register addresses
ADDR_REG_PARAM0     = 0x0000
ADDR_REG_PARAM5     = 0x0004
ADDR_REG_VERSION    = 0x0008
ADDR_REG_LED        = 0x0009
dataGpo             = 0x55555555

# Size of canvas to display image
nCanvasSizeX    = 700  # 
nCanvasSizeY    = 500  # 

nCropBoxPixX    = 48   # Box size in image pixels
nCropBoxPixY    = 48   # Box size in image pixels
nCropBoxDrawX   = 0    # Box size in canvas 
nCropBoxDrawY   = 0    # Box size in canvas 

xfactor = 0.0
yfactor = 0.0


#---------------------------------------------------------------
# Create the root dialog
#---------------------------------------------------------------
root = Tk()
root.title(strScriptVersion)
#root.geometry("300x350")    # Set the size of the app 
root.resizable(1, 1)        # Don't allow resizing in the x or y direction

strMsg              = StringVar()
strMsg1             = StringVar()

strAddrRegVersion   = StringVar()
strAddrRegVersion.set(str(hex(ADDR_REG_VERSION)))
strVersion          = StringVar()
print (strAddrRegVersion.get())
strVersion.set("- -") 

#---------------------------------------------------------------
# Create a parser object and parse the command line options 
#---------------------------------------------------------------
parser = ap.ArgumentParser(prog="GUI_demo_rheed", description = "Set image crop areas")
parser.add_argument('fileNameBase', default = 'none'  , help = 'Image file name base' )
parser.add_argument("-t", "--type", dest = 'fileType'   , choices = ['png', 'h5'], default = 'h5', help = 'Image file type: .h5 (default) or .png)')

#---------------------------------------------------------------
# Parse the argument list and then extract the settings
args                = parser.parse_args()
arg_fileNameBase    = args.fileNameBase
arg_fileType        = args.fileType
print ("Image filename base  = ", arg_fileNameBase)
print ("Image file type      = ", arg_fileType)

if (arg_fileType == 'none'):
    fileNameh5 = arg_fileNameBase + '.h5'
elif (arg_fileType == 'h5'):
    fileNameh5 = arg_fileNameBase + '.h5'

fileNamePng = arg_fileNameBase + '.png'

print ("Image filename H5   = ", fileNameh5)
print ("Image filename PNG  = ", fileNamePng)

#---------------------------------------------------------------
# Initialize the X,Y co-ordinates in the entry boxes
#---------------------------------------------------------------
listX = [] 
listY = [] 
for i in range(NUM_REGS):  
    listX.append(StringVar())
    listX[i].set(0)
    listY.append(StringVar())
    listY[i].set(0)

nListPtrEnd = 0 # point to next available list entry.    

#---------------------------------------------------------------
# Open the .h5 file, convert to a .png
#---------------------------------------------------------------
if (arg_fileType == 'none') or (arg_fileType == 'h5'):

        with h5py.File(fileNameh5, "r") as f:

            # Print all root level object names (aka keys) 
            # these can be group or dataset names 
            print("Keys: %s" % f.keys())
            # get first object name/key; may or may NOT be a group
            a_group_key = list(f.keys())[0]

            # get the object type for a_group_key: usually group or dataset
            print(type(f[a_group_key])) 

            # If a_group_key is a group name, 
            # this getsp the object names in the group and returns as a list
            data = list(f[a_group_key])

            # If a_group_key is a dataset name, 
            # this gets the dataset values and returns as a list
            data = list(f[a_group_key])
            # preferred methods to get dataset values:
            ds_obj = f[a_group_key]      # returns as a h5py dataset object
            ds_arr = f[a_group_key][()]  # returns as a numpy array
            max_value = np.max(ds_arr)
            print(" ")
            print('Image array:')
            print(ds_arr)
            print('Image shape:') 
            print(ds_arr.shape) 
            print('Image max value:')
            print(max_value)

            # Create image object from numpy array 
            data = Image.fromarray(ds_arr) 
              
            # saving the final output as a PNG file 
            data.save(fileNamePng) 


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
# Capture click location in Canvas and convert location to
# image pixel location
#---------------------------------------------------------------
def OnCanvasClick(event):                  

    global nListPtrEnd
    global listx
    global listy
    global nCanvasSizeX
    global nCanvasSizeY

    print ('Got canvas click', event.x, event.y)
    
    print   ('click_x , click_y ', event.x, event.y)
    pixel_x = event.x * xfactor
    pixel_y = event.y * yfactor
    print   ('pixel_x , pixel_y ', pixel_x, pixel_y)
    box_x0 = event.x - nCropBoxDrawX/2
    box_y0 = event.y - nCropBoxDrawY/2
    box_x1 = event.x + nCropBoxDrawX/2
    box_y1 = event.y + nCropBoxDrawY/2

    if (box_x0 < 0):
        box_x0 = 0
        box_x1 = nCropBoxDrawX

    if (box_y0 < 0):
        box_y0 = 0
        box_y1 = nCropBoxDrawY

    if (box_x1 > resize_width):
        box_x1 = resize_width
        box_x0 = resize_width - nCropBoxDrawX

    if (box_y1 > resize_height):
        box_y1 = resize_height
        box_y0 = resize_height - nCropBoxDrawY

    print ('box x0,y0' , box_x0, box_y0)
    print ('box x1,y1' , box_x1, box_y1)
    print ('ptr = '    , nListPtrEnd)

    box = canvas1.create_line((box_x0, box_y0), (box_x1, box_y0), (box_x1, box_y1), (box_x0, box_y1), (box_x0, box_y0), fill= 'red', width = 2)
    cross = canvas1.create_line((event.x-5, event.y  ), (event.x+5, event.y  ), fill= 'green', width = 2)
    cross = canvas1.create_line((event.x  , event.y-5), (event.x  , event.y+5), fill= 'green', width = 2)

    pixel_box_x0 = box_x0 / scale_factor
    pixel_box_y0 = box_y0 / scale_factor

    # Add first NUM_REGS box co-ordinates to the list
    if (nListPtrEnd < NUM_REGS) :
        listX[nListPtrEnd].set(math.floor(pixel_box_x0))
        listY[nListPtrEnd].set(math.floor(pixel_box_y0)) 
        nListPtrEnd+= 1

    # Additional box co-ordinates push older ones off the list
    else : 
        for nEntry in range(1, NUM_REGS) :
            listX[nEntry-1].set(listX[nEntry].get()) 
            listY[nEntry-1].set(listY[nEntry].get()) 

        listX[NUM_REGS-1].set(math.floor(pixel_box_x0))
        listY[NUM_REGS-1].set(math.floor(pixel_box_y0)) 
        

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

#-----------------------------------------------------------------------------------------------------------------------------
# Create the canvas to hold the image
#-----------------------------------------------------------------------------------------------------------------------------
#image = Image.open("D:/Work/Blob.png")
#image = Image.open("single_sample.png")
image = Image.open(fileNamePng)
image_width, image_height = image.size
print ('image width  = {0:8}' .format(image_width))
print ('image height = {0:8}' .format(image_height))

# Calculate the best scale factor to use for the image to fit the canvas while keeping the aspect ratio
xfactor = nCanvasSizeX/image_width      # e.g 700 / 1400 = 0.5
yfactor = nCanvasSizeY/image_height     # e.g.500 /  600 = 0.83  
scale_factor = min(xfactor, yfactor)    # We scale both dimensions by 0.5

# Resize the image to fit the canvas
resize_width  =  int(image_width*scale_factor)
resize_height =  int(image_height*scale_factor)
print ('image width resize  = {0:8}' .format(resize_width))
print ('image height resize = {0:8}' .format(resize_height))
img = image.resize((resize_width, resize_height))
resize_width, resize_height = img.size

# Calculate scale factors. xfactor * click_x = x pixel location in original image
xfactor = image_width/resize_width
yfactor = image_height/resize_height

nCropBoxDrawX   = nCropBoxPixX / xfactor  # Box size in canvas 
nCropBoxDrawY   = nCropBoxPixY / yfactor  # Box size in canvas 

canvas1 = Canvas(root, width=nCanvasSizeX, height=nCanvasSizeY, relief=SUNKEN, borderwidth=1)
canvas1.image = ImageTk.PhotoImage(img)     
canvas1.create_image(0, 0, image=canvas1.image, anchor='nw')
canvas1.pack()
canvas1.bind('<Button-1>', OnCanvasClick)                  

#-----------------------------------------------------------------------------------------------------------------------------
# Quit button
#-----------------------------------------------------------------------------------------------------------------------------
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

