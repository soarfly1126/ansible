#!/bin/bash

##
#   Check Info File
###
nat_log="/etc/bind/src/nat.log"
stack_log="/etc/bind/src/stack.log"
dns_log="/etc/bind/src/dns.log"

if [[ ! -f ${nat_log} ]];then
        echo "${nat_log} not exist."
        exit 1
fi

if [[ ! -f ${stack_log} ]];then
        echo "${stack_log} not exist."
        exit 1
fi

if [[ ! -f ${dns_log} ]];then
        echo "${dns_log} not exist."
        exit 1
fi

##
#       Catch DNS Info
###
private_limit=`cat stack.log | egrep -v "ACTIVE" | awk -F ":" '{print $2}' | wc -l`
nat_range=16
count=0
num=1
while [[ ${count} -lt ${private_limit} ]]; do
        ### NAT ###
        nat_private_ip=`cat stack.log | egrep -v "ACTIVE" | awk -F ":" '{print $2}' | head -n ${num} | tail -n 1`
        #echo ${num}". nat_private_ip="$nat_private_ip
        nat_private_24bit=`cat stack.log | egrep -v "ACTIVE" | awk -F ":" '{print $2}' | head -n ${num} | tail -n 1 | cut -d"." -f 1-3`
        #echo ${num}". nat_private_24bit="$nat_private_24bit
        nat_public_24bit=`cat nat.log | egrep -v "^$|^#" | grep "${nat_private_24bit}" | tail -n 1 | awk -F "-" '{print $2}' | cut -d'.' -f 1-3`
        #echo ${num}". nat_public_24bit="${nat_public_24bit}

        nat_private_ip_header=`cat nat.log | egrep -v "^$|^#" | grep "${nat_private_24bit}" | tail -n 1 | awk -F "-" '{print $1}'`
        #echo ${num}". nat_private_ip_header="$nat_private_ip_header
        nat_public_ip_header=`cat nat.log | egrep -v "^$|^#" | grep "${nat_private_24bit}" | tail -n 1 | awk -F "-" '{print $2}'`
        #echo ${num}". nat_public_ip_header="$nat_public_ip_header

        ### DNS ###
        tenant_name=`cat dns.log | egrep -v "^$|^#" | grep "${nat_private_24bit}" | awk -F "=" '{print $1}'`
        dns_private_8bit=`cat stack.log | egrep -v "ACTIVE" | awk -F ":" '{print $2}' | head -n ${num} | tail -n 1 | cut -d"." -f 4`
        dns_int_list[${count}]="${tenant_name}_int_${dns_private_8bit}"
        dns_int_pool[${count}]=$nat_private_ip

        ip_count=0
        while [[ ${ip_count} -lt ${nat_range} ]]; do
                private_count=`echo "$nat_private_ip_header" | cut -d"." -f 4`
                value=$((10#${private_count}+${ip_count}))
                scan_private_ip=$nat_private_24bit"."$value
                public_count=`echo "$nat_public_ip_header" | cut -d"." -f 4`
                value2=$((10#${public_count}+${ip_count}))
                scan_public_ip=$nat_public_24bit"."$value2

                if [[ "${nat_private_ip}" == "${scan_private_ip}" ]]; then
                        dns_public_8bit=`echo $scan_public_ip | cut -d"." -f 4`
                        dns_ext_list[${count}]="${tenant_name}_ext_${dns_public_8bit}"
                fi
                (( ip_count++ ))
        done
        (( count++ ))
        (( num++ ))
done

###
#       Demo Add Internal IP DNS
###
for ((i=0; i<${#dns_int_list[@]}; i++)); do
        chk_int_zone=`bash /etc/bind/src/dns.sh -s int -u list | grep ${dns_int_pool[$i]}`
        if [[ -z ${chk_int_zone} ]]; then
                bash /etc/bind/src/dns.sh -s int -u add -n ${dns_int_list[$i]} -i ${dns_int_pool[$i]}
        fi

done

###
#       Demo DNS
###
chk_int_zone_demo=`bash /etc/bind/src/dns.sh -s int -u list | grep "10.0.0.24"`
if [[ -z ${chk_int_zone_demo} ]]; then
        bash /etc/bind/src/dns.sh -s int -u add -n client_demo -i 10.0.0.24
fi
bash /etc/bind/src/dns.sh -s int -u list
