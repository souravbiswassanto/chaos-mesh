#!/bin/bash

while true; do
    clear
    echo "=== File Contents in /var/pv/lsn - $(date) ==="
    
    # Check if directory exists
    if [ -d "lsn" ]; then
        for file in lsn/*; do
            if [ -f "$file" ]; then
                echo "─────────────────────────────────────────"
                echo "File: $file"
                echo "Content:"
                cat "$file"
                echo
            fi
        done
    else
        echo "Directory 'lsn' not found!"
    fi
    
    echo "─────────────────────────────────────────"
    sleep 0.1
done
