#!/usr/bin/env python3
import serial
import threading
import time

PORT     = 'COM7'
BAUDRATE = 115200
INTERVAL = 10       # 100 microseconds

# The 4‐byte packet to send
DATA = bytes([0xC0, 0xFF, 0xFF, 0xFF])

# Event to signal threads to stop
stop_event = threading.Event()

def sender(ser):
    """Continuously send DATA every INTERVAL seconds (busy‐wait)."""
    next_time = time.perf_counter()
    while not stop_event.is_set():
        ser.write(DATA)
        next_time += INTERVAL
        # Busy‐wait/sleep until the next send time
        while True:
            now = time.perf_counter()
            if now >= next_time or stop_event.is_set():
                break
            # bill small sleep to yield CPU
            time.sleep(0.00001)

def receiver(ser):
    """Continuously read and print any incoming bytes."""
    while not stop_event.is_set():
        n = ser.in_waiting
        if n:
            incoming = ser.read(n)
            print("Received:", ' '.join(f"{b:02X}" for b in incoming))
        # a short sleep to avoid 100% CPU
        time.sleep(0.0001)

def main():
    # Open serial port
    ser = serial.Serial(
        port=PORT,
        baudrate=BAUDRATE,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0,        # non‐blocking reads
    )

    # Give the port some time to settle
    time.sleep(2)
    print(f"Port {PORT} opened at {BAUDRATE} baud. Sending every {INTERVAL*1e6:.0f} µs.")

    # Spawn sender & receiver threads
    tx = threading.Thread(target=sender,   args=(ser,), daemon=True)
    rx = threading.Thread(target=receiver, args=(ser,), daemon=True)
    tx.start()
    rx.start()

    try:
        # Keep main thread alive until Ctrl+C
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user—stopping...")
        stop_event.set()
        tx.join()
        rx.join()
    finally:
        ser.close()
        print("Serial port closed.")

if __name__ == "__main__":
    main()
