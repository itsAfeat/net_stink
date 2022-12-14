#!/bin/bash

# Help menu information
_prg_name="NET STINK"
_cmd_name="net_stink"
_version="1.0"
_link="https://github.com/itsAfeat/net_stink"

# Operation flags to do
do_clear=0
do_port=0
do_fast=0
do_save=0
file_name=""

# Hide ^C
stty -echoctl

# Include the colors script
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/colors.sh"

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
    is_root=0
else
    is_root=1
fi


##Functions
# Help menu function
function help_menu() {
    echo -e "\n${Bold}${_prg_name}${Color_Off} $_version ( $_link )"
    echo -e "Usage: ${_cmd_name} ${Italic}[parameters] -i [ip_range]${Color_Off}"
    echo -e "\n${HWhite}${Underline}PARAMTERS${Color_Off}"
    echo -e "${Italic}${Bold}\t-h${Color_Off}\t\tThe help menu, what you're looking at dummy."
    echo -e "${Italic}${Bold}\t-i [x.x.x.x]${Color_Off}\tIp range. The range in which the program shold scan in.\n\t\t\t(ex: 192.168.0.* or 192.168.0.0/16)"
    echo -e "${Italic}${Bold}\t-p [x-y]${Color_Off}\tPort range. Same as ip range... but with ports.\n\t\t\t(ex: 443-8080)"
    echo -e "${Italic}${Bold}\t-f${Color_Off}\t\tDo a fast scan. This will make the scan faster, but\n\t\t\tit will also be less accurate."
    echo -e "${Italic}${Bold}\t-o [file]${Color_Off}\tLog that sweet scan to a file."
    echo -e "${Italic}${Bold}\t-c${Color_Off}\t\tClear the terminal at the start of the scan."
}

# Show and hide the cursor
function show_cursor() {
    tput cnorm
}

function hide_cursor() {
    tput civis
}


# Get all the flags and set their corresponding values
while getopts i:p:o:fhc flag
do
    case "${flag}" in
        i) ip_range=${OPTARG};;
        p) port_range=${OPTARG}; do_port=1;;
        o) file_name=${OPTARG}; do_save=1;;
        f) do_fast=1;;
        h) help_menu; exit;;
        c) do_clear=1;;
    esac
done

# Check if the ip range has been set, if not... show the help menu
if [ -z ${ip_range+x} ]; then
    help_menu
    exit
fi

# the arrays and dictionary for the ips and ports it finds
open_ips=()
open_ports=()
declare -A ip_dict

if [ $do_clear -eq 1 ]; then
    clear
else
    echo -e -n "\n"
fi

#trap show_cursor INT TERM
#hide_cursor

echo -e "${Bold}${Yellow}[!]${Color_Off} Starting host scan\n\n"

if [ $do_fast -eq 1 ]; then
    timeout=2
else
    timeout=4
fi

if [ $do_save -eq 0 ]; then
    for i in {0..255}; do
        # Replace every * in the ip with whatever i is
        ip=$(sed "s/*/$i/g" <<< "$ip_range")
        
        _ping=$(ping -W $timeout -c 1 $ip)
        # Grab the loss percentage to check if the host is up or not
        result=$(echo "$_ping" | awk '/loss/ {print $6}')
        echo -e "\e[1A\e[K> ${Italic}$ip${Color_Off}"
        if [ "$result" != "100%" ]; then
            # If the user is up, aka we get some sort of responds from them, print the ip and add it to the open_ips array
            echo -e "\e[1A\e[K${Bold}${Green}[+]${Color_Off} $ip\n"
            open_ips+=("$ip")
        fi
    done

    echo -e "\n${Bold}${Yellow}[!]${Color_Off} ${Italic}$_prg_name${Color_Off} found ${#open_ips[@]} open host(s)..."

    if [ $do_port -eq 1 ]; then
        echo -e "${Bold}${Yellow}[!]${Color_Off} Starting port scan\n"
        for ip in "${open_ips[@]}"; do
            # Use netcat to check which ports are open in the given port range
            open_ports=$(nc -z -vv -n $ip $port_range 2>&1 | awk '/open/ {print $3" "($4)}')

            # Check if any ports where found, if not the open_ports array's first element will be an empty string
            if [ -z "${open_ports[0]}" ]; then
                # Set the value in the dictionary to something recognizable
                ip_dict["$ip"]="-1"
            else
                ip_dict["$ip"]=$open_ports  
            fi
        done

        echo -e "${Bold}${Green}[+]${Color_Off}Scan finished... Showing results below"
        echo -e "\n--------------------------------------------------------------"

        for key in "${!ip_dict[@]}"; do
            echo -e "${Bold}${Purple}[>]${Color_Off} $key"
            if [ "${ip_dict[$key]}" = "-1" ]; then
                echo -e "\t${Italic}${Bold}No open ports${Color_Off}\n"
            else
                echo -e "\t${Italic}${Bold}${ip_dict[$key]}${Color_Off}\n"
            fi
        done
    fi
else
    # Everything here is more or less the same as above, just with less outputs and more of that whole saving action
    echo -e "\e[1A\e[K${Italic}Scanning..."
    
    echo -e "\t\tHost scan results" > $file_name
    echo -e "-------------------------------------------------\n" >> $file_name

    for i in {0..255}; do
        tmp_ip=$(sed "s/*/$i/g" <<< "$ip_range")
        
        _ping=$(ping -W $timeout -c 1 $tmp_ip)
        result=$(echo "$_ping" | awk '/loss/ {print $6}')
        if [ "$result" != "100%" ]; then
            ip=$(echo "$_ping" | awk '/PING/ {print $2}')
            echo "[+] $ip" >> $file_name
            open_ips+=("$ip")
        fi
    done

    if [ $do_port -eq 1 ]; then
        echo -e "\n${Bold}${Yellow}[!]${Color_Off} Starting port scan\n"
        echo -e "${Italic}Scanning..."
        for ip in "${open_ips[@]}"; do
            open_ports=$(nc -z -vv -n $ip $port_range 2>&1 | awk '/open/ {print $3" "($4)}')

            if [ -z "${open_ports[0]}" ]; then
                ip_dict["$ip"]="-1"
            else
                ip_dict["$ip"]=$open_ports  
            fi
        done

        echo -e "\n-----------------------------------------------" >> $file_name
        echo -e "\n\n\t\tPort scan results" >> $file_name
        echo -e "-------------------------------------------------" >> $file_name

        for key in "${!ip_dict[@]}"; do
            echo -e "\n[+] $key" >> $file_name
            if [ "${ip_dict[$key]}" = "-1" ]; then
                echo -e "\tNo open ports\n" >> $file_name
            else
                echo -e "\t${ip_dict[$key]}\n" >> $file_name 
            fi
        done
    fi
fi

#show_cursor
exit
