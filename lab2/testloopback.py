import serial
import threading

# Configure the serial port
ser = serial.Serial(
   port='COM7',  # Replace with your serial port
   baudrate=115200,
   bytesize=serial.EIGHTBITS,
   parity=serial.PARITY_NONE,
   stopbits=serial.STOPBITS_ONE,
   timeout=1
)

def read_from_port():
   """Function to read data from the serial port."""
   while True:
      if ser.in_waiting > 0:
         data = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
         print(f"Received: {data}")

try:
   # Open the serial port if not already open
   if not ser.is_open:
      ser.open()

   # Start a thread to read from the serial port
   read_thread = threading.Thread(target=read_from_port, daemon=True)
   read_thread.start()

   # Send 0xFF
   ser.write(bytes([0xFF]))

   # Send an arbitrary message
   message = "Hello, Loopback!"  # Replace with your message
   ser.write(message.encode('utf-8'))

   # Send 0xF1
   ser.write(bytes([0xF1]))

   print("Data sent successfully. Press Ctrl+C to exit.")

   # Keep the main thread alive
   while True:
      pass

except serial.SerialException as e:
   print(f"Serial error: {e}")

except KeyboardInterrupt:
   print("\nExiting...")

finally:
   # Close the serial port
   if ser.is_open:
      ser.close()