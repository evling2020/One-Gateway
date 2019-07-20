#!/bin/sh
###########################################################
# checkpsw.sh (C) 2016 Yiang Guo
# Modified from http://openvpn.se/files/other/checkpsw.sh
# Original Author: 2004 Mathias Sundman <mathias@openvpn.se>
# 
# This script will authenticate OpenVPN users against
# a salted SHA512 file. The passfile should simply contain
# one row per user with the following info in its order:
# username salt hashed password
# 
# Each column seperated by one or more space(s) or tab(s).
# 
# Hashed password is the SHA512 of password followed by salt.
# Password file example:
# 1 2 5aadb45520dcd8726b2822a7a78bb53d794f557199d5d4abdedd2c55a4bd6ca73607605c558de3db80c8e86c3196484566163ed1327e82e8b6757d1932113cb8
# 
# Username and password are passed by environment variable:
# username and password
# 
# http://openvpn.se/files/other/checkpsw.sh
# make sure openvpn user has permission with following files:

PASSFILE="/vpn/config/users"
TIME_STAMP=`date "+%Y-%m-%d %T"`

###########################################################

if [ ! -r "${PASSFILE}" ]; then
	    exit 1
    fi

    SALT=`awk '!/^;/&&!/^#/&&$1=="'${username}'"{print $2;exit}' ${PASSFILE}`
    HASHED_PASSWORD=`awk '!/^;/&&!/^#/&&$1=="'${username}'"{print $3;exit}' ${PASSFILE}`

    if [ "${HASHED_PASSWORD}" = "" ]; then 
	        exit 1
	fi

	HASH_RESULT=`printf "${password}${SALT}" | sha512sum | awk '{printf $1}'`

	if [ "${HASH_RESULT}" = "${HASHED_PASSWORD}" ]; then 
		    exit 0
	    fi

	    exit 1
