#!/bin/sh

rtl_433 -F json 2>/dev/null | /home/vlysenkov/xopok-scripts/monitoring/co2/local/sdr.py
