def install_and_import(package, package_name=None):
    if package_name is None:
        package_name = package

    import importlib
    try:
        importlib.import_module(package)
    except ImportError:
        import pip
        pip.main(['install', package_name])
    finally:
        globals()[package] = importlib.import_module(package)

install_and_import("serial", "pyserial")
install_and_import("PIL", "pillow")
install_and_import("tqdm")
install_and_import("numpy")
install_and_import("scipy")


from serial import Serial
import serial.tools.list_ports
from tqdm import tqdm

from PIL import Image

from scipy.signal import convolve2d
import numpy as np

IMAGE_NAME2="test2.png"
IMAGE_NAME1="test1.png"

BASYS3_PID=0x6010
BASYS3_VID=0x0403

IMG_HEIGHT=256
IMG_WIDTH=256

dev=""
for port in serial.tools.list_ports.comports():
    if(port.vid==BASYS3_VID and port.pid==BASYS3_PID):
        dev=port.device

if not dev:
    raise RuntimeError("Basys 3 Not Found!")

test_n=int(input("Insert test number (1 or 2): ").strip())

if(test_n not in [1,2]):
    raise RuntimeError("Test numer must be be 1 or 2")

dev=Serial(dev,115200)

img=Image.open(IMAGE_NAME1 if test_n==1 else IMAGE_NAME2)
mat=np.asarray(img,dtype=np.uint8)

mat=mat[:,:,:3]
if(mat.max()>127):
    mat=mat//2

buff=mat.tobytes()

mat=np.sum(mat,axis=2)//3

sim_img=convolve2d(mat,[[-1,-1,-1],[-1,8,-1],[-1,-1,-1]], mode="same")

sim_img[sim_img<0]=0
sim_img[sim_img>127]=127

# Write the start byte
dev.write(b'\xff')
print("Sent byte: 0xff")

# Write the image data row by row
for i in tqdm(range(IMG_HEIGHT)):
    row_data = buff[(i)*IMG_WIDTH*3:(i+1)*IMG_WIDTH*3]
    dev.write(row_data)

res = bytearray()
expected_bytes = IMG_HEIGHT * IMG_WIDTH + 2

# Write the end byte
dev.write(b'\xf1')
print("Sent byte: 0xf1")
dev.flush()

with open("received_bytes_ok_fix.log", "w") as log_file:
    while len(res) < expected_bytes:
        byte = dev.read(1)
        if byte:
            res.append(byte[0])
            log_file.write(f"Received byte number {len(res)}/{expected_bytes}: {byte[0]:02x}\n")

res_img=np.frombuffer(res[1:-1],dtype=np.uint8)

res_img=res_img.reshape((IMG_HEIGHT,IMG_WIDTH))

im=Image.fromarray(np.uint8(res_img))
im.show()

assert np.all(res_img==sim_img), "Image Mismatch!"

