#!/bin/bash

local_path=`pwd`
nat_log=${local_path}/nat.log
stack_log=${local_path}/stack.log

if [[ ! -f ${nat_log} ]]; then
        echo "[ERROR][F5] ${nat_log} FILE NOT FOUND."
        exit 1
fi

if [[ ! -f ${stack_log} ]]; then
        echo "[ERROR][F5] ${stack_log} FILE NOT FOUND."
        exit 1
fi

private_limit=`cat ${stack_log} | wc -l`
nat_private_header_start=101
count=0
num=1
while [[ ${count} -lt ${private_limit} ]]; do
        ### STACK PRIVATE IP
        nat_private_ip=`cat ${stack_log} | head -n ${num} | tail -n 1`
        nat_private_tenant=`echo "${nat_private_ip}" | cut -d"." -f 1-3`
        nat_private_header=`echo "${nat_private_ip}" | cut -d"." -f 4`

        ### CHECK STACK PRIVATE IP HAVE PUBLIC IP EXIST
        chk_nat=`cat ${nat_log} | grep "${nat_private_tenant}" | awk -F "-" '{print $2}'`
        if [[ "${chk_nat}" != "None" ]]; then
                ### STACK PUBLIC IP
                nat_public_start_ip=`echo "${chk_nat}"`
                nat_public_tenant=`echo "${nat_public_start_ip}" | cut -d'.' -f 1-3`
                nat_public_header_start=`echo "${nat_public_start_ip}" | cut -d'.' -f 4`
                if [[ -z ${nat_public_tenant} ]]; then
                        echo "[ERROR][F5] ${nat_private_tenant} NOT FOUND."
                        exit 1
                fi
                
                nat_private_diff=$((10#${nat_private_header}-10#${nat_private_header_start}))
                if [[ ${nat_private_diff} -lt 0 ]] && [[ ${nat_private_diff} -ge 16 ]]; then
                        echo "[ERROR][F5] ${nat_private_diff} NUMBER IS PROBLEM BETWEEN THE TWO NUMBERS."
                        exit 1
                fi

                nat_public_header=$((10#${nat_public_header_start}+10#${nat_private_diff}))
                nat_public_ip=`echo ${nat_public_tenant}"."${nat_public_header}`

                ### NAT
                nat_name="NAT_${nat_private_ip}"
                nat_list=`tmsh list ltm nat "${nat_name}" 2>&1`
                chk_nat_list=`echo ${nat_list} | egrep -v "not found"`
                if [[ ! -z ${chk_nat_list} ]]; then
                        tmsh delete ltm nat "${nat_name}" > /dev/null 2>&1
                fi
                tmsh create ltm nat ${nat_name} originating-address ${nat_private_ip} translation-address ${nat_public_ip}
        fi
        (( count++ ))
        (( num++ ))
done

###
#   Result
###
echo ""
echo "---------------------"
echo "[Result Mapping List]"
echo "---------------------"
tmsh list ltm nat
