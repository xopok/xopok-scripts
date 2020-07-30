#!/bin/sh

rtl_433 -F json 2>/dev/null | ./sdr.py
