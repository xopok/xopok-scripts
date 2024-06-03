#!/bin/sh

# How to install:
# 1. Adjust the path to the sdr.py file below.
# 2. Install the rtl-433 using apt, as usual.
# 3. Install the service:
#   a. `sudo ln -fs `realpath ./rtl_433.service` /etc/systemd/system/`
#   b. `sudo service rtl_433 start`
#   c. `sudo systemctl status rtl_433.service` - check that it's running.

rtl_433 -F json 2>/dev/null | /home/vlysenkov/xopok-scripts/monitoring/co2/local/sdr.py
