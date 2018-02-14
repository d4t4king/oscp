#!/bin/bash

sortips() 
{
	sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | uniq
}

CRUMBS_DIR="/root/.crumbs"
LOG='initial-setup.log'
WORKING_DIR=$1
DATA_DIR="${WORKING_DIR}/.raw_data"

if [ ! -d ${CRUMBS_DIR} ]; then
	mkdir ${CRUMBS_DIR}
fi

if [ -e ${CRUMBS_DIR}/setup.done ]; then
	echo "Setup already done."
else
	# delete the log file if it exists
	# start fresh (lol)
	if [ -f $LOG ]; then
		rm -f $LOG
	fi

	# complain if it looks like we didn't get a starting point
	# on the command line
	if [ "${1}x" == "x" ]; then
		echo "Trying specifying a working directory!"
		echo "Like: ./${0} /path/to/data/dir"
		echo "Sheepishly refusing to continue without a directory."
		exit 255
	fi

	if [ ! -e $WORKING_DIR ]; then
		mkdir -p $WORKING_DIR
		mkdir -p $DATA_DIR
	fi
	touch ${CRUMBS_DIR}/setup.done
fi
pushd $WORKING_DIR

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
echo "=				(¯\`·._.·[ START INITIAL-SETUP LOG  ]·._.·´¯)" >> $LOG
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
echo "LOG=${LOG}" >> $LOG
echo "WORKING_DIR=${WORKING_DIR}" >> $LOG
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG

# clone the nmap2db.pl repo if it doesn't already exist.
if [ ! -d /root/nmap2db.pl ]; then
	pushd /root
	git clone https://github.com/d4t4king/nmap2db.pl
	popd
fi

# Get an initial assessment of the area.....what is up?
# we're probably missing stuff, this is just a quick and dirty
# first pass
if [ -e ${CRUMBS_DIR}/pingsweep.done ]; then
	echo "Ping sweep already done."
else
	echo -n "Running ping sweep...." | tee -a $LOG
	nmap -sn -oG ${DATA_DIR}/pingsweep.gnmap 10.11.1.0/24 >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/pingsweep.done
fi
if [ -e ${CRUMBS_DIR}/hosts.sorted.done ]; then
	echo "Up hosts already sorted."
else
	echo -n "Sorting up hosts...." | tee -a $LOG
	grep "Status: Up" ${DATA_DIR}/pingsweep.gnmap | cut -d" " -f2 | sortips > ${DATA_DIR}/uphosts.list
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/hosts.sorted.done
fi
# now we know what's up, let's see what they're offering
if [ -e ${CRUMBS_DIR}/quickscan.done ]; then
	echo "Quick scan already done."
else
	echo -n "Running the initial quick scan...." | tee -a $LOG
	nmap -sS -T4 --reason -A -oA ${DATA_DIR}/quickscan -iL ${DATA_DIR}/uphosts.list >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/quickscan.done
fi
if [ -e ${CRUMBS_DIR}/udpscan.done ]; then
	echo "UDP scan already done."
else
	echo -n "Running UDP scan for NTP and SNMP...." | tee -a $LOG
	nmap -sU -p 53,123,161 -oA ${DATA_DIR}/udpscan -iL ${DATA_DIR}/uphosts.list >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/udpscan.done
fi
if [ -e ${CRUMBS_DIR}/nmap2db.done ]; then
	echo "nmap2db already done."
else
	echo -n "Storing quick scan results in sqlite...." | tee -a $LOG
	/root/nmap2db.pl/nmap2db -i ${DATA_DIR}/quickscan.xml -d nmaps.db -t sqlite >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/nmap2db.done
fi
if [ -e ${CRUMBS_DIR}/allports.done ]; then
	echo "Nmap on all ports done."
else
	echo -n "Spinning off detailed scans for up hosts...." | tee -a $LOG
	for IP in ${DATA_DIR}/uphosts.list; do
		screen -dm bash -c "nmap -sS -p0-65535 -T4 -oA ${DATA_DIR}/detail_${IP} --reason ${IP}\r\n"
	done
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/allports.done
fi
if [ -e ${CRUMBS_DIR}/sqlite1.done ]; then
	echo "MS08-067 targets already queried."
else
	echo -n "Querying for MS08-067 candidates...." | tee -a $LOG
	sqlite3 nmaps.db "select ip4 from vw_ports_on_host where product like '%windows 2000%' or product like '%windows 2003' or product like '%windows xp%';" > ${DATA_DIR}/lowfruit.list
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/sqlite1.done
fi
if [ -e ${CRUMBS_DIR}/ms08067.nmap.done ]; then
	echo "MS08-067 targets scanned."
else
	echo -n "Checking MS08-067...." | tee -a $LOG
	nmap -sV -p 445 --script smb-vuln-ms08-067 -oA ${DATA_DIR}/ms08067 -iL ${DATA_DIR}/lowfruit.list >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/ms08067.nmap.done
fi
if [ -e ${CRUMBS_DIR}/eternal1.done ]; then
	echo "EternalBlue targets queried."
else
	echo -n "Querying for Eternal Blue candidates...." | tee -a $LOG
	sqlite3 nmaps.db "select ip4 from vw_ports_on_host where product like '%windows 7%' or product like '%windows 2008%' or product like '%windows 10%' or product like '%windows 2012%';" > ${DATA_DIR}/eternal.list
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/eternal1.done
fi
if [ -e ${CRUMBS_DIR}/eternal.nmap.done ]; then
	echo "EternalBlue nmap done."
else
	echo -n "Checking MS17-010...." | tee -a $LOG
	nmap -sV -p 445 --script smb-vuln-ms17-010 -oA ${DATA_DIR}/ms17010 -iL ${DATA_DIR}/eternal.list >> $LOG 2>&1
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/eternal.nmap.done
fi
if [ -e ${CRUMBS_DIR}/eternal.msf.done ]; then
	echo "EternelBlue MSF enumeration done."
else
	echo -n "Checking eternal blue with metasploit....." | tee -a $LOG
	for H in $(cat ${DATA_DIR}/ms17010.gnmap | grep "Status: Up" | cut -d" " -f2 | sortips | uniq); do 
		msfconsole -q -x "use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $H; run; exit" 2>&1
	done | grep -E "(VULNERABLE|INFECTED)" | cut -d" " -f2 | cut -d: -f1 | sortips | uniq > ${DATA_DIR}/ms17010_msf.txt
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/eternal.msf.done
fi
if [ -e ${CRUMBS_DIR}/snmp.msf.done ]; then
	echo "MSF SNMP user enumeration done."
else
	echo -n "Enumerating users via SNMP....." | tee -a $LOG
	for H in $(grep "161/open/udp" ${DATA_DIR}/quickscan.gnmap | cut -d" " -f2 | sortips); do
		msfconsole -q -x "color false; use auxiliary/scanner/snmp/snmp_enumusers; set RHOSTS ${H}; run; exit;" 2>&1
	done | grep -E "Found [0-9]+ users:" | cut -d" " -f2,6- | sed -e 's/:161/: /g' > snmp_users.list
	echo "done." | tee -a $LOG
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
	touch ${CRUMBS_DIR}/snmp.msf.done
fi
echo -n "Waiting for any remaining screens...." | tee -a $LOG
while [[ $(screen -ls | grep -c "Detached") > 0 ]]; do
	echo -n "."
	sleep 10
done
echo "done." | tee -a $LOG
if [ -e ${CRUMBS_DIR}/finalsort.done ]; then
	echo "Final sorting is done."
else
	echo -n "Final sorting....."
	# integrated into setup
	#mkdir "${WORKING_DIR}/.raw_data"
	#mv *.gnmap *.nmap *.xml ${WORKING_DIR}/.raw_data/
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='21';" | sortips > ftp.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='22';" | sortips > ssh.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='23';" | sortips > telnet.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='25';" | sortips > smtp.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='53';" | sortips > dns.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='80' or port_num='8000' or port_num='8080';" | sortips > http.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='88';" | sortips > kerberos.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='110' or port_num='995';" | sortips > pop3.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='119';" | sortips > nntp.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='123';" | sortips > ntp.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='143' or port_num='993';" | sortips > imap.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='389' or port_num='636';" | sortips > ldap.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='445';" | sortips > smb.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='631';" | sortips > cups.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='1433';" | sortips > mssql.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='1521';" | sortips > oracle.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='3306';" | sortips > mysql.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='3389';" | sortips > rdp.hosts
	sqlite3 nmaps.db "select ipv4_addr from vw_hosts_on_port where port_num='5900' or port_num='5800' or port_num='5901';" | sortips > vnc.hosts
	echo "done." | tee -a $LOG
	touch ${CRUMBS_DIR}/finalsort.done
fi
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG
echo "=				(¯\`·._.·[ END INITIAL-SETUP LOG ]·._.·´¯)" >> $LOG
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $LOG

