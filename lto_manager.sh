#!/bin/bash

LOGFILE=/var/log/lto-events.log



function check_devices(){

    lsscsi | grep -i 'tape' &> /dev/null 
    echo $?
}

function ask_path_dir(){

    while read -p "Enter a correct path (/media/HDD) to Directory: " DIR ; 
    do
        if [ -d "$DIR" ]; then
            echo "$DIR"
            break;
        fi
    done

}

function ask_label(){
   while read -p "Enter a correct Label ( BesiNR, VNR ) : " LABEL ; 
   do
        if [ -n "$LABEL" ]; then
             echo "$LABEL"
            break;
         fi
      done
 }

function ask_tape_device(){

    declare -A devices
    ######## Search LTO 6 und LTO 7 by Serial Number ####################
    local d=$1
    if [[ $d -eq 1 ]]; then
       lto6=$(lsscsi -g | tr -s ' ' | grep "ULTRIUM-HH6" | cut -d' ' -f7)
       lto7=$(lsscsi -g | tr -s ' ' | grep "ULTRIUM-HH7" | cut -d' ' -f7)
    else
       lto6=$(lsscsi -g | tr -s ' ' | grep "ULTRIUM-HH6" | cut -d' ' -f6)
       lto7=$(lsscsi -g | tr -s ' ' | grep "ULTRIUM-HH7" | cut -d' ' -f6)
    fi

    devices=(["LTO6"]=$lto6 ["LTO7"]=$lto7)

    while read -p "Enter correct LTO(n) for your Tape-Device 6,7: " TAPE_DEVICE ; 
    do
        if [ -e ${devices[LTO$TAPE_DEVICE]} ]; then
            echo ${devices[LTO$TAPE_DEVICE]}
            break;
        fi
    done
}

function conform(){

    while read -n1  -p " [y]es|[n]o :" && [[ $REPLY != q ]]; 
    do
        case $REPLY in
        y|Y|J|j) answer='y'; break;;
        n|N) answer='n'; break;;
        *) echo "What?";;
        esac
    done
    echo $answer
}

function menu_0(){

    # Dir - Tar - Lto
    echo "Give me a source path: "
    DIR=`ask_path_dir`
    echo "Source $DIR is a Directory..."
    echo ""

    echo "Give me a Label for a Tape: "
    LABEL=`ask_label`
    echo "Label is $LABEL ..."
    echo ""

    check_d=$(check_devices)
    if [[ $check_d -eq 1 ]]; then
        echo "YOU don't have LTOs"
        exit 1
    else
        echo "List of Tapes "; lsscsi | grep -i 'tape'
    fi
    echo ""
    echo "Give me a LTO Device: "
    DEVICE=`ask_tape_device`
    echo "LTO Device $DEVICE can be used..."
    echo ""
    msg="Start Backup $DIR >>>>> TarArchive ($LABEL) >>>>>>> MBUFFER >>>> LTO $DEVICE"
    echo $msg
    conf=$( conform )
    if [ "$conf" == "y" ]; then
        echo ""
        echo "Start Backup..."
        echo "$(date)"
	if [[ 1 || $TAPE_DEVICE -eq 7 ]];
	   then
              # LTO 7 wird mit 95% des RAMS als Buffer gestartet
              # KD - war der auskommentierte TAR Befehl bis 15.11.2022 
              # (tar -cf - $DIR --record-size=500k --label="$LABEL" | mbuffer -s 500k -P 100 -m 80% -o $DEVICE) && mt -f $DEVICE rewoffl
	      (tar -cf - "$DIR" --record-size=500k --label="$LABEL" -b 1000 | mbuffer -s 500k -P 100 -m 80% -o $DEVICE) && mt -f $DEVICE rewoffl 

              #testLeo Param -p einsetzen um Buffer ab 50% wieder zu lesesn zu lassen letzter funktionierender Befehl drüber
	      #(tar -cf - $DIR --record-size=500k --label="$LABEL" -b 1000 | mbuffer -s 500k -P 100 -p 50 -m 90% -o $DEVICE) && mt -f $DEVICE rewoffl
	   else
              # LTO 6 wird mit einer Temp-Datei als Bufferspeicher auf der NVME gestartet
              # KD - war der auskommentierte TAR-Befehl bis 15.11.2022
              # (tar -cf - $DIR --record-size=500k --label="$LABEL" | mbuffer -T /mnt/LTO6Buffer/LTO6.buffer -s 500k -P 100 -m 64G -o $DEVICE) && mt -f $DEVICE rewoffl
               (tar -cf - "$DIR" --record-size=500k --label="$LABEL" -b 1000 | mbuffer -T /mnt/LTO6Buffer/LTO6.buffer -s 500k -P 100 -m 64G -o $DEVICE) && mt -f $DEVICE rewoffl 

	      #testLeo Param -p einsetzen um Buffer ab 50% wieder zu lesesn zu lassen letzter funktionierender Befehl drüber
              #(tar -cf - $DIR --record-size=500k --label="$LABEL" -b 1000 | mbuffer -T /mnt/LTO6Buffer/LTO6.buffer -s 500k -P 100 -p 50 -m 64G -o $DEVICE) && mt -f $DEVICE rewoffl
	fi
        echo "End Backup $(date)"
    else
        echo "Break......"
    fi
}



function menu_1(){

    # LTO--- MBUFFER--- TAR--- DIR
    echo "$1"
    check_d=$(check_devices) 
    if [[ $check_d -eq 1 ]]; then
        echo "YOU don't have LTOs"
        exit 1
       else
        echo "List of Tapes "; lsscsi | grep -i 'tape'
     fi

    echo "Give me a LTO Device: "
    DEVICE=`ask_tape_device`
    echo "LTO Device $DEVICE can be used..."
    echo "Give me a source path: "
    DIR=`ask_path_dir`
    echo "Source $DIR is a Directory..."
    echo ""
    echo ""
    msg="Start Backup $DIR >>>>> TarArchive >>>>>>> MBUFFER >>>> LTO$DEVICE"
    echo $msg
    conf=$( conform )
    if [ "$conf" == "y" ]; then
        echo ""
        echo "Start Backup..."
	cd $DIR
        mbuffer -s 500k -i $DEVICE   | tar --record-size=500k -xvf - 
    else
        echo ""
        echo ""
        echo "Break......"
    fi
}

function menu_2(){

    # TAR-Label (in der Regel die BesiNr) abfragen
    echo "$1"
    check_d=$(check_devices) 
    if [[ $check_d -eq 1 ]]; then
        echo "YOU don't have LTOs"
        exit 1
       else
        echo "List of Tapes "; lsscsi | grep -i 'tape'
     fi

    echo "Give me a LTO Device: "
    DEVICE=`ask_tape_device`
    tar --test-label  --record-size=500k -f $DEVICE

}

# NOT USED
#
#function menu_3(){
#
#    # LTO--- MBUFFER--- TAR--- DIR
#    echo "$1"
#    check_d=$(check_devices) 
#    if [[ $check_d -eq 1 ]]; then
#        echo "YOU don't have LTOs"
#        exit 1
#       else
#        echo "List of Tapes "; lsscsi | grep -i 'tape'
#     fi
#
#    echo "Give me a LTO Device: "
#    DEVICE=`ask_tape_device`
#    tar --test-label  --record-size=500k -f $DEVICE
#}
#

function menu_4(){

    # Destroy LTFs / Erase Tape
    
    check_d=$(check_devices) 
    if [[ $check_d -eq 1 ]]; then
        echo "YOU don't have LTOs"
        exit 1
       else
        echo "List of Tapes "; lsscsi -g | grep -i 'tape'
     fi
    echo "" 
    echo "Give me a LTO Device: "
    DEVICE=` ask_tape_device 1 `
    #echo "$DEVICE"
    msg="Start destroy LTO$DEVICE"
    echo $msg
    conf=$( conform )
    if [ "$conf" == "y" ]; then
	/root/ITDT/itdt -f $DEVICE  load rmp rewind erase 
	if [ $? == "0" ]; then
		echo ""
		echo ""
		echo "********************************"
		echo "*** Loeschen erfolgreich ;-) ***"
		echo "********************************"
		echo ""
                /root/ITDT/itdt -f $DEVICE unload
		#mt -f $DEVICE rewoffl
	else 
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!ERROR - Loeschen war nicht erfolgreich!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo ""
	fi
	 
    else
        echo "Break......"
    fi
}

function choose_from_menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
    printf "$prompt\n"
    while true
    do
        # list all options (option list is zero-based)
        index=0 
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]
            then echo -e " >\e[7m$o\e[0m" # mark & highlight the current option
            else echo "  $o"
            fi
            index=$(( $index + 1 ))
        done
        read -s -n3 key # wait for user to key in arrows or ENTER
        if [[ $key == $esc[A ]] # up arrow
        then cur=$(( $cur - 1 ))
            [ "$cur" -lt 0 ] && cur=0
        elif [[ $key == $esc[B ]] # down arrow
        then cur=$(( $cur + 1 ))
            [ "$cur" -ge $count ] && cur=$(( $count - 1 ))
        elif [[ $key == "" ]] # nothing, i.e the read delimiter - ENTER
        then break
        fi
        echo -en "\e[${count}A" # go up to the beginning to re-render
    done
    # export the selection to the requested output variable
    #printf -v $outvar "${options[$cur]}"
    printf -v $outvar "${cur}"
}






################## Main ################################################

#if [ $EUID -ne 0 ]; then
#   echo "Please run as root !"
#   exit
#fi



main_menu=(
"         1. Backup Directory --> TarArchive --> MBUFFER --> LTO                          "
"         2. LTO --> MBUFFER -->  TarArchive --> Backup Directory                         "
"         3. Show Tar Label                                                               " 
"         4. Destroy LTFS-Partitions on LTO / Erase LTO                                   "
"         5. Quit                                                                         "
)
clear
choose_from_menu "Please make a choice:" menu "${main_menu[@]}"
echo ""
echo "Selected choice: $menu"
case $menu in 

  0)
    clear; echo "${main_menu[$menu]}"; echo ; menu_0 
    ;;

  1)
    clear; echo "${main_menu[$menu]}"; echo ; menu_1
    ;;

  2)
    clear; echo "${main_menu[$menu]}"; echo ; menu_2
    ;;
  3)
    clear; echo "${main_menu[$menu]}"; echo ; menu_4
    ;;

  4)
    clear; echo "${main_menu[$menu]}"; echo ; exit
    ;;

  *)
    echo -n "unknown"
    ;;
esac
