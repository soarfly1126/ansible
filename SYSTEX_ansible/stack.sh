#!/bin/bash

source /home/stack/overcloudrc

local_path=`pwd`
pid=`echo $$`
openstack stack list | egrep -v "^#|^$|^\+" | grep "CREATE_COMPLETE" | sed s/[[:space:]]//g > ${local_path}/tmp_${pid}.log

stack_status=`cat ${local_path}/tmp_${pid}.log`
if [[ -z "$stack_status" ]]; then
	echo "[ERROR][OPENSTACK] CREATE VM FAILURE."
	exit 1
fi

stack_limit=`cat ${local_path}/tmp_${pid}.log | wc -l`
count=0
num=1
while [ $count -lt $stack_limit ]; do
	# Catch Stack Floating_IP
        array_stack_id[$count]=`sed -n "${num}p" ${local_path}/tmp_${pid}.log | awk -F "|" '{print $2}'`
        ext_ip[$count]=`openstack stack show ${array_stack_id[$count]} | grep  -A1 "output_key: server1_public_ip" | sed s/[[:space:]]//g | awk -F "|" '{print $3}' | grep "output_value" | awk -F ":" '{print $2}'`
        # Catch Floating_IP ID
        ext_ip_id[$count]=`openstack floating ip list | grep ${ext_ip[$count]}" " | awk -F "|" '{print $2}' | sed s/[[:space:]]//g`
        # Catch Floating IP Status
        ext_ip_status[$count]=`openstack floating ip show ${ext_ip_id[$count]} | grep "status" | awk -F "|" '{print $3}' | sed s/[[:space:]]//g`

        if [[ "${ext_ip_status[$count]}" == "ACTIVE" ]]; then
                ### echo "Ext_IP:${ext_ip[$count]}" >> ${local_path}/stack_${pid}.log
                ### echo "Ext_IP_Status:${ext_ip_status[$count]}" >> ${local_path}/stack_${pid}.log
                echo "${ext_ip[$count]}" >> ${local_path}/stack_${pid}.log
        fi
        (( count++ ))
        (( num++ ))
done

if [[ -f ${local_path}/stack_${pid}.log ]]; then
        cp ${local_path}/stack_${pid}.log ${local_path}/stack.log
        sudo rm ${local_path}/stack_${pid}.log
fi

if [[ -f ${local_path}/tmp_${pid}.log ]]; then
        sudo rm ${local_path}/tmp_${pid}.log
fi
