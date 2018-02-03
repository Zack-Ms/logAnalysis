#!/bin/bash
##########################################
# log analysis main shell
# version: 3.0
# 
# DESC:
# 	读取邮件接收者（可配置多个邮件接收人）
# 	动态分析日志（可配置多个项目日志）
# PS:
#	所有使用到的配置文件必须是linux文件
##########################################

#配置 邮件接收人、项目信息、日志名称
email_receiver="/opt/script/config/email_receiver"
PID="/opt/script/config/PID"
log_name=""

email=`sed '/^#/d' ${email_receiver}`
ip=`/sbin/ifconfig | grep 'inet'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{print $1}' | head -1`
log_date=`date +"%Y-%m-%d" -d "-1 days"`
make_date=`date +%Y-%m-%d" "%H":"%M`
analysis_result="";

function canvas() {
	h_r=""
	for (( i = 0; i < ${1}; i++ )); do
		h_r="${h_r}-"
	done
	echo "${h_r}"
}

function analysis() {
	temp="/opt/script/config/temp"
	log_path=${2}
	error_count=`grep -c 'ERROR' ${log_path}`
	grep -A1 'ERROR' ${log_path} > ${temp}
	sed -i '/^-/d;/ERROR/d;/INFO/d;/WARN/d;/DEBUG/d' ${temp}
	analysis_result="  `canvas 44` \n    ${1} \n    ERROR : ${error_count}"
	declare -A map=()
	while read line
	do
		key=`echo ${line} | cut -d ':' -f 1 | awk -F "." '{print $NF}'`
		if [ "${map[${key}]}" == "" ]; then
			map["${key}"]=1
		else
 			let map["${key}"]++
		fi
	done < ${temp}
	for key in ${!map[@]}
	do
		analysis_result="${analysis_result} \n    ${key} : ${map[$key]}"
	done
	rm -rf ${temp}
}

if [ "${log_name}" = "" ]; then
	log_name="monitor.log.${log_date}.log"
fi
email_content="    LOG_ANALYSIS \n    IP : ${ip} \n    make_date : ${make_date} \n"
while read line
do
	if [ "${line:0:1}" != "#" ] && [[ -n ${line} ]]; then
		OIFS=${IFS}; IFS=" "; set -- ${line}; p_name=${1};p_path=${2} IFS=${OIFS}
		if [ -f "${p_path}.${log_date}.log" ]; then
			analysis ${p_name} "${p_path}.${log_date}.log"
			email_content="${email_content} \n\n ${analysis_result}"
		fi
	fi
done < ${PID}
email_content="${email_content}\n"`canvas 44`

echo -e "${email_content}" | mail -s "Log statistics | CBS-${ip}" ${email}
exit 0
