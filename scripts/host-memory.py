#!/usr/bin/env python3
import psutil

def main():
    memory = psutil.virtual_memory()
    free_gb = round(memory.available / (1024**3), 1)
    total_gb = round(memory.total / (1024**3), 1)
    print(f'Host Memory: Free={free_gb} GB / Total={total_gb} GB')

if __name__ == '__main__':
    main()