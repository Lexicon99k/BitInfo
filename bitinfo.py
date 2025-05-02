import platform
import os
import sys

def get_system_info():
    # System architecture (32-bit or 64-bit)
    architecture = platform.architecture()
    bit_info = architecture[0]  # e.g., '64bit' or '32bit'

    # Operating system details
    os_name = platform.system()  # e.g., 'Windows', 'Linux', 'Darwin' (macOS)
    os_version = platform.version()  # OS version
    os_release = platform.release()  # OS release

    # Machine type (e.g., 'x86_64', 'AMD64')
    machine_type = platform.machine()

    # Python version
    python_version = platform.python_version()

    # Current working directory
    current_directory = os.getcwd()

    # Print all the information
    print("=== System Information ===")
    print(f"Architecture: {bit_info}")
    print(f"Operating System: {os_name} {os_release} (Version: {os_version})")
    print(f"Machine Type: {machine_type}")
    print(f"Python Version: {python_version}")
    print(f"Current Working Directory: {current_directory}")

if __name__ == "__main__":
    get_system_info()
