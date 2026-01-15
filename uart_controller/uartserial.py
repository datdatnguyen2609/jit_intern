#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FPGA Integrated System GUI
FPGA Nexys A7-100T - UART 115200 baud
"""

import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
import re
from datetime import datetime


BAUDRATE = 115200
REFRESH_RATE_MS = 100


class FPGAIntegratedGUI:
    def __init__(self, root):
        self.root = root
        self.root. title("FPGA Nexys A7 - Integrated System")
        self.root.geometry("850x700")
        
        # Serial
        self.ser = None
        self.running = False
        self.rx_buffer = ""
        
        # Data
        self.accel_x = 0
        self. accel_y = 0
        self.accel_z = 0
        self.temperature = 0.0
        self.switch_value = 0
        self.pc_led_value = 0
        self.current_mode = 0
        
        # Counters
        self. rx_count = 0
        self.tx_count = 0
        
        # Flag
        self.updating_checkboxes = False
        self.log_text = None  # Khởi tạo trước
        
        # Build UI
        self. build_ui()
        
        # Start refresh
        self.refresh_ui()

    def build_ui(self):
        main_frame = ttk.Frame(self. root, padding=5)
        main_frame.pack(fill="both", expand=True)
        
        # Connection
        self.build_connection_frame(main_frame)
        
        # Notebook
        self.notebook = ttk. Notebook(main_frame)
        self.notebook.pack(fill="both", expand=True, pady=5)
        
        # Tabs
        self.tab_control = ttk.Frame(self. notebook)
        self.notebook.add(self.tab_control, text="Control")
        
        self.tab_monitor = ttk.Frame(self.notebook)
        self.notebook.add(self. tab_monitor, text="Monitor")
        
        self.tab_log = ttk.Frame(self.notebook)
        self.notebook.add(self. tab_log, text="UART Log")
        
        # Build tabs - Log tab TRƯỚC để log_text tồn tại
        self.build_log_tab()
        self.build_control_tab()
        self.build_monitor_tab()
        
        # Status bar
        self. build_status_bar(main_frame)

    def build_connection_frame(self, parent):
        frame = ttk.LabelFrame(parent, text="UART Connection", padding=5)
        frame.pack(fill="x", pady=(0, 5))
        
        ttk.Label(frame, text="Port:").pack(side="left", padx=(0, 5))
        
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(
            frame,
            textvariable=self.port_var,
            width=15,
            state="readonly"
        )
        self.port_combo.pack(side="left", padx=(0, 5))
        
        # Get ports
        ports = self.list_ports()
        self.port_combo["values"] = ports
        if ports:
            self.port_combo. current(0)
        
        ttk. Button(frame, text="Refresh", command=self.refresh_ports_btn, width=8).pack(side="left", padx=(0, 10))
        
        self.btn_connect = ttk.Button(frame, text="Connect", command=self.toggle_connect, width=10)
        self.btn_connect.pack(side="left", padx=(0, 10))
        
        ttk.Label(frame, text=f"Baud:  {BAUDRATE}").pack(side="left", padx=10)
        
        self.conn_label = ttk.Label(frame, text="●", foreground="gray", font=("Arial", 14))
        self.conn_label.pack(side="right", padx=5)

    def build_control_tab(self):
        # Mode Display
        frame_mode = ttk.LabelFrame(self.tab_control, text="Current Mode", padding=5)
        frame_mode.pack(fill="x", padx=10, pady=5)
        
        mode_info = [
            ("M0: Accel", "BTNU"),
            ("M1: Temp", "BTNL"),
            ("M2: SW->LED", "BTNR"),
            ("M3: PC->LED", "BTND"),
            ("M4: Combined", "BTNC")
        ]
        
        self.mode_labels = []
        mode_container = ttk.Frame(frame_mode)
        mode_container.pack(fill="x", pady=5)
        
        for i, (name, btn) in enumerate(mode_info):
            lbl = tk.Label(
                mode_container,
                text=f"{name}\n({btn})",
                width=12,
                height=3,
                relief="groove",
                bg="lightgray"
            )
            lbl.pack(side="left", padx=3, expand=True, fill="x")
            self.mode_labels. append(lbl)

        # LED Control
        frame_led = ttk. LabelFrame(self.tab_control, text="LED Control (PC -> FPGA)", padding=5)
        frame_led.pack(fill="x", padx=10, pady=5)
        
        # Hex input
        row1 = ttk. Frame(frame_led)
        row1.pack(fill="x", pady=5)
        
        ttk. Label(row1, text="Hex (0000-FFFF):").pack(side="left")
        self.led_entry = ttk.Entry(row1, width=10, font=("Consolas", 12))
        self.led_entry.insert(0, "0000")
        self.led_entry. pack(side="left", padx=5)
        self.led_entry. bind("<Return>", lambda e: self.send_led_hex())
        
        ttk.Button(row1, text="Send", command=self.send_led_hex, width=8).pack(side="left", padx=5)
        
        # Quick buttons
        row2 = ttk.Frame(frame_led)
        row2.pack(fill="x", pady=5)
        
        ttk.Label(row2, text="Quick:").pack(side="left")
        quick_vals = [
            ("OFF", 0x0000),
            ("Low8", 0x00FF),
            ("High8", 0xFF00),
            ("Alt1", 0x5555),
            ("Alt2", 0xAAAA),
            ("ALL", 0xFFFF)
        ]
        for name, val in quick_vals:
            btn = ttk.Button(row2, text=name, width=6)
            btn.config(command=lambda v=val: self. send_led_16bit(v))
            btn.pack(side="left", padx=2)

        # LED Checkboxes
        frame_cbs = ttk.LabelFrame(frame_led, text="Individual LEDs", padding=5)
        frame_cbs.pack(fill="x", pady=5)
        
        self.led_vars = []
        
        # Row 1: LED 0-7
        row_led1 = ttk. Frame(frame_cbs)
        row_led1.pack(fill="x", pady=2)
        ttk.Label(row_led1, text="LED 0-7:", width=10).pack(side="left")
        for i in range(8):
            var = tk.IntVar(value=0)
            self.led_vars.append(var)
            cb = ttk. Checkbutton(row_led1, text=str(i), variable=var, command=self.on_checkbox_click)
            cb.pack(side="left", padx=5)
        
        # Row 2: LED 8-15
        row_led2 = ttk.Frame(frame_cbs)
        row_led2.pack(fill="x", pady=2)
        ttk. Label(row_led2, text="LED 8-15:", width=10).pack(side="left")
        for i in range(8, 16):
            var = tk.IntVar(value=0)
            self.led_vars.append(var)
            cb = ttk. Checkbutton(row_led2, text=str(i), variable=var, command=self.on_checkbox_click)
            cb.pack(side="left", padx=5)
        
        # Current value
        self.led_value_label = ttk.Label(frame_led, text="Current: 0x0000", font=("Consolas", 12))
        self.led_value_label.pack(pady=5)

        # Raw Send
        frame_raw = ttk.LabelFrame(self.tab_control, text="Raw UART Send", padding=5)
        frame_raw.pack(fill="x", padx=10, pady=5)
        
        self.raw_entry = ttk.Entry(frame_raw, width=40, font=("Consolas", 10))
        self.raw_entry.pack(side="left", padx=5, pady=5)
        self.raw_entry.bind("<Return>", lambda e: self.send_raw_ascii())
        
        ttk.Button(frame_raw, text="Send ASCII", command=self. send_raw_ascii).pack(side="left", padx=3)
        ttk.Button(frame_raw, text="Send HEX", command=self.send_raw_hex).pack(side="left", padx=3)

    def build_monitor_tab(self):
        # Accelerometer
        frame_accel = ttk.LabelFrame(self.tab_monitor, text="Accelerometer ADXL362", padding=10)
        frame_accel.pack(fill="x", padx=10, pady=5)
        
        accel_row = ttk.Frame(frame_accel)
        accel_row.pack(pady=10)
        
        # X
        x_frame = ttk.Frame(accel_row)
        x_frame.pack(side="left", padx=30)
        ttk.Label(x_frame, text="X", font=("Arial", 12, "bold")).pack()
        self.accel_x_label = ttk.Label(x_frame, text="+000", font=("Consolas", 24, "bold"), foreground="red")
        self.accel_x_label.pack()
        
        # Y
        y_frame = ttk. Frame(accel_row)
        y_frame.pack(side="left", padx=30)
        ttk.Label(y_frame, text="Y", font=("Arial", 12, "bold")).pack()
        self.accel_y_label = ttk.Label(y_frame, text="+000", font=("Consolas", 24, "bold"), foreground="green")
        self.accel_y_label.pack()
        
        # Z
        z_frame = ttk.Frame(accel_row)
        z_frame.pack(side="left", padx=30)
        ttk.Label(z_frame, text="Z", font=("Arial", 12, "bold")).pack()
        self.accel_z_label = ttk. Label(z_frame, text="+000", font=("Consolas", 24, "bold"), foreground="blue")
        self.accel_z_label. pack()

        # Temperature
        frame_temp = ttk.LabelFrame(self. tab_monitor, text="Temperature ADT7420", padding=10)
        frame_temp.pack(fill="x", padx=10, pady=5)
        
        self.temp_label = ttk.Label(frame_temp, text="--.-°C", font=("Consolas", 32, "bold"))
        self.temp_label.pack(pady=10)

        # Switch Status
        frame_sw = ttk.LabelFrame(self. tab_monitor, text="Switch Status SW[15: 0]", padding=10)
        frame_sw.pack(fill="x", padx=10, pady=5)
        
        self.sw_hex_label = ttk.Label(frame_sw, text="SW:  0x0000", font=("Consolas", 18, "bold"))
        self.sw_hex_label.pack(pady=5)
        
        sw_row = ttk.Frame(frame_sw)
        sw_row.pack(pady=5)
        
        self.sw_indicators = []
        for i in range(15, -1, -1):
            lbl = tk.Label(sw_row, text=str(i), width=3, height=2, relief="groove", bg="gray", font=("Arial", 8))
            lbl.pack(side="left", padx=1)
            self.sw_indicators.append(lbl)
        
        self.sw_binary_label = ttk.Label(frame_sw, text="0000_0000_0000_0000", font=("Consolas", 12))
        self.sw_binary_label.pack(pady=5)

        # PC LED Status
        frame_pc = ttk.LabelFrame(self. tab_monitor, text="PC LED Status", padding=10)
        frame_pc. pack(fill="x", padx=10, pady=5)
        
        self.pc_led_label = ttk. Label(frame_pc, text="PC LED: 0x0000", font=("Consolas", 18, "bold"))
        self.pc_led_label. pack(pady=10)

    def build_log_tab(self):
        # Controls
        ctrl_frame = ttk.Frame(self. tab_log)
        ctrl_frame. pack(fill="x", padx=10, pady=5)
        
        ttk.Button(ctrl_frame, text="Clear", command=self.clear_log).pack(side="left", padx=5)
        
        self.autoscroll_var = tk.IntVar(value=1)
        ttk.Checkbutton(ctrl_frame, text="Auto-scroll", variable=self. autoscroll_var).pack(side="left", padx=10)
        
        self.show_raw_var = tk. IntVar(value=0)
        ttk.Checkbutton(ctrl_frame, text="Show Raw", variable=self. show_raw_var).pack(side="left", padx=10)
        
        # Log text
        log_frame = ttk.Frame(self.tab_log)
        log_frame.pack(fill="both", expand=True, padx=10, pady=5)
        
        self.log_text = tk.Text(log_frame, height=15, font=("Consolas", 10), state="disabled")
        self.log_text.pack(side="left", fill="both", expand=True)
        
        scrollbar = ttk. Scrollbar(log_frame, command=self.log_text.yview)
        scrollbar. pack(side="right", fill="y")
        self.log_text.config(yscrollcommand=scrollbar.set)
        
        # Tags
        self.log_text.tag_configure("tx", foreground="blue")
        self.log_text.tag_configure("rx", foreground="green")
        self.log_text.tag_configure("error", foreground="red")
        self.log_text.tag_configure("info", foreground="gray")

    def build_status_bar(self, parent):
        status_frame = ttk.Frame(parent)
        status_frame.pack(fill="x", pady=(5, 0))
        
        self. status_var = tk.StringVar(value="Disconnected")
        ttk.Label(status_frame, textvariable=self. status_var, relief="sunken").pack(side="left", fill="x", expand=True)
        
        self. rx_count_var = tk.StringVar(value="RX: 0")
        ttk. Label(status_frame, textvariable=self.rx_count_var, relief="sunken", width=12).pack(side="right")
        
        self.tx_count_var = tk. StringVar(value="TX: 0")
        ttk. Label(status_frame, textvariable=self.tx_count_var, relief="sunken", width=12).pack(side="right")

    # ========================================================================
    # Port Management
    # ========================================================================
    def list_ports(self):
        return [p.device for p in serial.tools.list_ports. comports()]

    def refresh_ports_btn(self):
        ports = self.list_ports()
        self.port_combo["values"] = ports
        if ports: 
            self.port_combo.current(0)
        self.log_msg("Ports refreshed", "info")

    # ========================================================================
    # Connection
    # ========================================================================
    def toggle_connect(self):
        if self.ser: 
            self.disconnect()
        else:
            self.connect()

    def connect(self):
        port = self.port_var.get()
        if not port: 
            messagebox.showerror("Error", "Select a COM port")
            return
            
        try: 
            self.ser = serial.Serial(port, BAUDRATE, timeout=0.1)
            self.running = True
            self.rx_count = 0
            self.tx_count = 0
            
            self.rx_thread = threading.Thread(target=self.rx_loop, daemon=True)
            self.rx_thread.start()
            
            self.btn_connect.config(text="Disconnect")
            self.conn_label.config(foreground="green")
            self.status_var.set(f"Connected:  {port}")
            self.log_msg(f"Connected to {port}", "info")
            
        except Exception as e:
            messagebox.showerror("Error", str(e))
            self.log_msg(f"Error:  {e}", "error")

    def disconnect(self):
        self.running = False
        time.sleep(0.2)
        
        if self.ser:
            try:
                self. ser.close()
            except:
                pass
            self. ser = None
        
        self.btn_connect.config(text="Connect")
        self.conn_label.config(foreground="gray")
        self.status_var.set("Disconnected")
        self.log_msg("Disconnected", "info")

    # ========================================================================
    # TX Functions
    # ========================================================================
    def send_led_16bit(self, value):
        if not self.ser:
            messagebox.showwarning("Warning", "Not connected")
            return
            
        value = value & 0xFFFF
        low_byte = value & 0xFF
        high_byte = (value >> 8) & 0xFF
        
        try:
            self. ser.write(bytes([low_byte, high_byte]))
            self.tx_count += 2
            self.tx_count_var. set(f"TX: {self. tx_count}")
            
            self.pc_led_value = value
            self. update_led_display()
            self.log_msg(f"TX -> 0x{value: 04X} [0x{low_byte:02X}, 0x{high_byte:02X}]", "tx")
            
        except Exception as e:
            self.log_msg(f"TX Error: {e}", "error")

    def send_led_hex(self):
        try:
            text = self.led_entry. get().strip().upper().replace("0X", "")
            value = int(text, 16)
            if value < 0 or value > 0xFFFF: 
                raise ValueError("Out of range")
            self.send_led_16bit(value)
        except ValueError as e:
            messagebox.showerror("Error", f"Invalid HEX\n{e}")

    def on_checkbox_click(self):
        if self. updating_checkboxes:
            return
            
        value = 0
        for i, var in enumerate(self. led_vars):
            if var.get():
                value |= (1 << i)
        
        self.led_entry.delete(0, tk.END)
        self.led_entry.insert(0, f"{value:04X}")
        self.send_led_16bit(value)

    def update_led_display(self):
        self.led_value_label.config(text=f"Current: 0x{self.pc_led_value:04X}")
        self.pc_led_label. config(text=f"PC LED: 0x{self.pc_led_value:04X}")
        
        self.updating_checkboxes = True
        for i, var in enumerate(self.led_vars):
            var.set(1 if (self.pc_led_value & (1 << i)) else 0)
        self.updating_checkboxes = False

    def send_raw_ascii(self):
        if not self.ser:
            return
        text = self.raw_entry.get()
        if not text:
            return
        try:
            data = text.encode('ascii')
            self.ser.write(data)
            self.tx_count += len(data)
            self.tx_count_var.set(f"TX: {self.tx_count}")
            self.log_msg(f"TX -> '{text}'", "tx")
        except Exception as e:
            self. log_msg(f"Error: {e}", "error")

    def send_raw_hex(self):
        if not self.ser:
            return
        hex_str = self.raw_entry.get().replace(" ", "").replace("0x", "").replace("0X", "")
        if not hex_str:
            return
        try: 
            data = bytes. fromhex(hex_str)
            self.ser.write(data)
            self.tx_count += len(data)
            self.tx_count_var. set(f"TX: {self.tx_count}")
            self.log_msg(f"TX HEX -> {data.hex().upper()}", "tx")
        except Exception as e:
            self.log_msg(f"Error:  {e}", "error")

    # ========================================================================
    # RX Thread
    # ========================================================================
    def rx_loop(self):
        while self. running:
            try:
                if self.ser and self.ser.in_waiting:
                    data = self. ser.read(self.ser.in_waiting)
                    self.rx_count += len(data)
                    
                    # Update counter
                    self.root.after(0, self.update_rx_count)
                    
                    # Show raw
                    if self. show_raw_var.get():
                        hex_str = data.hex().upper()
                        self. root.after(0, lambda h=hex_str:  self.log_msg(f"RX RAW <- [{h}]", "rx"))
                    
                    # Process text
                    try:
                        text = data.decode('ascii', errors='replace')
                        self. rx_buffer += text
                        self.root.after(0, self.process_rx_buffer)
                    except: 
                        pass
                        
            except Exception as e: 
                if self.running:
                    err_msg = str(e)
                    self.root. after(0, lambda m=err_msg: self.log_msg(f"RX Error: {m}", "error"))
            
            time.sleep(0.01)

    def update_rx_count(self):
        self.rx_count_var.set(f"RX:  {self.rx_count}")

    def process_rx_buffer(self):
        while '\n' in self. rx_buffer: 
            line, self. rx_buffer = self.rx_buffer. split('\n', 1)
            line = line.strip()
            if line: 
                self.parse_rx_line(line)

    def parse_rx_line(self, line):
        self.log_msg(f"RX <- {line}", "rx")
        
        try:
            # Mode 0: M0:X=+xxx Y=+xxx Z=+xxx
            if line.startswith("M0:"):
                self.current_mode = 0
                match = re.search(r'X=([+-]?\d+)\s+Y=([+-]?\d+)\s+Z=([+-]?\d+)', line)
                if match: 
                    self.accel_x = int(match.group(1))
                    self.accel_y = int(match.group(2))
                    self. accel_z = int(match.group(3))
            
            # Mode 1: M1:T=xx. xxC
            elif line. startswith("M1:"):
                self.current_mode = 1
                match = re.search(r'T=(\d+)\.(\d+)C', line)
                if match: 
                    int_part = int(match. group(1))
                    frac_part = int(match.group(2))
                    self.temperature = int_part + frac_part / 100.0
            
            # Mode 2: M2:SW=xxxx
            elif line.startswith("M2:"):
                self.current_mode = 2
                match = re.search(r'SW=([0-9A-Fa-f]{4})', line)
                if match: 
                    self. switch_value = int(match.group(1), 16)
            
            # Mode 3: M3:RX=xx L=xxxx
            elif line.startswith("M3:"):
                self.current_mode = 3
                match = re.search(r'L=([0-9A-Fa-f]{4})', line)
                if match: 
                    self. pc_led_value = int(match.group(1), 16)
            
            # Mode 4: M4:X=+xxx T=xxC S=xxxx
            elif line.startswith("M4:"):
                self.current_mode = 4
                
                match_x = re.search(r'X=([+-]?\d+)', line)
                if match_x: 
                    self.accel_x = int(match_x. group(1))
                
                match_t = re.search(r'T=(\d+)C', line)
                if match_t: 
                    self. temperature = float(match_t. group(1))
                
                match_s = re. search(r'S=([0-9A-Fa-f]{4})', line)
                if match_s: 
                    self.switch_value = int(match_s.group(1), 16)
                    
        except Exception as e: 
            self.log_msg(f"Parse error: {e}", "error")

    # ========================================================================
    # UI Refresh
    # ========================================================================
    def refresh_ui(self):
        self.update_mode_display()
        self.update_accel_display()
        self.update_temp_display()
        self.update_switch_display()
        
        self.root.after(REFRESH_RATE_MS, self.refresh_ui)

    def update_mode_display(self):
        colors = ["#FFCCCC", "#CCFFCC", "#CCCCFF", "#FFFFCC", "#CCFFFF"]
        for i, lbl in enumerate(self.mode_labels):
            if i == self.current_mode:
                lbl.config(relief="raised", bg=colors[i])
            else: 
                lbl.config(relief="groove", bg="lightgray")

    def update_accel_display(self):
        self.accel_x_label.config(text=f"{self.accel_x:+4d}")
        self.accel_y_label.config(text=f"{self.accel_y:+4d}")
        self.accel_z_label.config(text=f"{self.accel_z:+4d}")

    def update_temp_display(self):
        self.temp_label.config(text=f"{self. temperature:.2f}°C")

    def update_switch_display(self):
        self.sw_hex_label.config(text=f"SW: 0x{self.switch_value:04X}")
        
        binary = f"{self.switch_value:016b}"
        binary_fmt = f"{binary[0:4]}_{binary[4:8]}_{binary[8:12]}_{binary[12:16]}"
        self. sw_binary_label.config(text=binary_fmt)
        
        for i, lbl in enumerate(self.sw_indicators):
            bit_pos = 15 - i
            if self.switch_value & (1 << bit_pos):
                lbl.config(bg="lime")
            else: 
                lbl.config(bg="gray")

    # ========================================================================
    # Log
    # ========================================================================
    def log_msg(self, msg, tag="info"):
        if self.log_text is None:
            return
            
        self.log_text. config(state="normal")
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text. insert("end", f"[{timestamp}] ", "info")
        self.log_text.insert("end", msg + "\n", tag)
        
        if self.autoscroll_var. get():
            self.log_text. see("end")
            
        self.log_text.config(state="disabled")

    def clear_log(self):
        if self.log_text is None:
            return
        self.log_text. config(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.config(state="disabled")


def main():
    root = tk.Tk()
    app = FPGAIntegratedGUI(root)
    
    def on_closing():
        if app.ser:
            app. disconnect()
        root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()


if __name__ == "__main__": 
    main()