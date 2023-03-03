#!/bin/bash

ext_file="/etc/bind/zones/external/db.f5.example.com"
ext_backup="/etc/bind/zones/external/db.f5.example.com.bk"
ext_tmp="/etc/bind/zones/external/db.f5.example.com.tmp"
int_file="/etc/bind/zones/internal/db.f5.example.com"
int_backup="/etc/bind/zones/internal/db.f5.example.com.bk"
int_tmp="/etc/bind/zones/internal/db.f5.example.com.tmp"
basedir=$(dirname ${0})
domain=f5.example.com

function print_help(){
        echo "====================================================================="
        echo "Usage: ${0} -s ext|int -u add|del|list -n servername -i record_value"
        echo "Example: "
        echo "${0} -s int -u add -n client1 -i 10.0.0.24"
        echo "${0} -s ext -u add -n ext1 -i 10.241.62.106"
        echo "${0} -s int -u del -n client1 -i 10.0.0.24"
        echo "${0} -s ext -u del -n ext1 -i 10.241.62.106"
        echo "${0} -s ext -u list "
        echo "====================================================================="
        exit 1
}

function check_external_zone(){
        if [ ! -f "${ext_file}" ]; then
                echo "=== external zone file not exist. ==="
                exit 1
        fi
}

function check_internal_zone(){
        if [ ! -f "${int_file}" ]; then
                echo "=== internal zone file not exist. ==="
                exit 1
        fi
}

function check_servername(){
        echo $servername | grep -wq ${domain}
        if [[ $? -eq 0 ]]; then
                hostname=$(echo $servername | cut -d. -f1)
                echo "=== '${servername}' is malformed. Servername should be just '${hostname}' without the '${domain}' ==="
                exit 1
        fi
        if [[ $servername =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "=== '${servername}' is malformed. Servername should not IP address. ==="
                exit 1
        fi
}

function check_fqdn(){
        echo $record_value | grep -q '\.'
        if [[ $? -ne 0 ]]; then
                echo "=== '${record_value}' is malformed. Should be a FQDN ==="
                exit 1
        fi
}

function update_record(){
        if [[ $action == "add" ]]; then
                if [ ${record_zone} == "int" ]; then
                        if grep -q "${record_value}" "${int_file}"; then
                                chk_servername=`cat "${int_file}" | grep "${servername} IN A ${record_value}" | cut -d' ' -f1`
                                # Avoid duplicate names
                                chk_servername=`echo $chk_servername | cut -d' ' -f1`
                                if [ "${chk_servername}" != "${servername}" ]; then
                                        echo "${servername} IN A ${record_value}" >> ${int_file}
                                        sudo systemctl restart bind9
                                else
                                        echo "=== Already exist record ==="
                                fi
                        else
                                cat "${int_file}" | grep -wq "${servername}"
                                if [[ $? -eq 0 ]]; then
                                        echo "=== [servername] already exist record ==="
                                else
                                        echo "${servername} IN A ${record_value}" >> ${int_file}
                                        sudo systemctl restart bind9
                                fi
                        fi
                else
                        if grep -q "${record_value}" "${ext_file}"; then
                                #echo "=== IP already exists in the record. ==="
                                chk_servername=`cat "${ext_file}" | grep "${servername} IN A ${record_value}" | cut -d' ' -f1`
                                # Avoid duplicate names
                                chk_servername=`echo $chk_servername | cut -d' ' -f1`
                                if [ "${chk_servername}" != "${servername}" ]; then
                                        echo "${servername} IN A ${record_value}" >> ${ext_file}
                                        sudo systemctl restart bind9
                                else
                                        echo "=== Already exist record ==="
                                fi
                        else
                                cat "${int_file}" | grep -wq "${servername}"
                                if [[ $? -eq 0 ]]; then
                                        echo "=== [servername] already exist record ==="
                                else
                                        echo "${servername} IN A ${record_value}" >> ${int_file}
                                        sudo systemctl restart bind9
                                fi
                        fi
                fi
        fi

        if [[ $action == "delete" ]]; then
                if [ ${record_zone} == "int" ]; then
                        chk_record=`cat "${int_file}" | grep "${servername} IN A ${record_value}" | cut -d' ' -f1`
                        # Avoid duplicate names
                        chk_record=`echo $chk_record | cut -d' ' -f1`
                        if [ "${chk_record}" == "${servername}" ]; then
                                echo "del [${servername} IN A ${record_value}] record"
                                sed "/${servername} IN A ${record_value}/d" ${int_file} > ${int_tmp}
                                cp ${int_file} ${int_backup}
                                cp ${int_tmp} ${int_file}
                                rm ${int_tmp}
                                sudo systemctl restart bind9
                        else
                                echo "=== No search this record, please check list ==="
                        fi
                else
                        chk_record=`cat "${ext_file}" | grep "${servername} IN A ${record_value}" | cut -d' ' -f1`
                        # Avoid duplicate names
                        chk_record=`echo $chk_record | cut -d' ' -f1`
                        if [ "${chk_record}" == "${servername}" ]; then
                                echo "del [${servername} IN A ${record_value}] record"
                                sed "/$servername IN A $record_value/d" ${ext_file} > ${ext_tmp}
                                cp ${ext_file} ${ext_backup}
                                cp ${ext_tmp} ${ext_file}
                                rm ${ext_tmp}
                                sudo systemctl restart bind9
                        else
                                echo "=== No search this record, please check list ==="
                        fi
                fi
        fi
}

function list_record(){
        if [[ $action == "list" ]]; then
                if [ ${record_zone} == "int" ]; then
                        cat "${int_file}" | grep "IN A"
                else
                        cat "${ext_file}" | grep "IN A"
                fi
        fi
}

while getopts "s:u:n:i:" opts
do
        case "$opts" in
                "s")
                        record_zone=$OPTARG
                        ;;
                "u")
                        action=$OPTARG
                        ;;
                "n")
                        servername=$OPTARG
                        ;;
                "i")
                        record_value=$OPTARG
                        ;;
                *)
                        print_help
                        ;;
        esac
done

if [[ -z "$record_zone" ]] || [[ -z "$action" ]] || [[ -z "$servername" ]] && [[ -z "$record_value" ]]; then
        case "$action" in
                "list")
                        action=list
                        ;;
                *)
                        print_help
                        ;;
        esac
        case "$record_zone" in
                "int")
                        list_record
                        ;;
                "ext")
                        list_record
                        ;;
                *)
                        print_help
                        ;;
        esac
        exit 0
fi

if [[ -z "$record_zone" ]] || [[ -z "$action" ]] || [[ -z "$servername" ]] || [[ -z "$record_value" ]]; then
        print_help
else
        case "$action" in
                "add")
                        action=add
                        ;;
                "del")
                        action=delete
                        ;;
                *)
                        print_help
                        ;;
        esac
        case "$record_zone" in
                "int")
                        check_servername
                        check_fqdn
                        check_internal_zone
                        update_record
                        ;;
                "ext")
                        check_servername
                        check_fqdn
                        check_external_zone
                        update_record
                        ;;
                *)
                        print_help
                        ;;
        esac
fi
