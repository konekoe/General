#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


# $1 ERRTYPE $2 ERR_MSG $3 ERR_CMD
write_error_json() {
    if [ -z "$3" ]; then
        jq -n \
          --arg et "$1" \
          --arg em "$2" \
          '{error_type: $et, error_msg: $em}' > /home/student/grader/error.json
    else
        jq -n \
          --arg et "$1" \
          --arg em "$2" \
          --arg ec "$3" \
          '{error_type: $et, error_msg: $em, error_cmd: $ec}' > /home/student/grader/error.json
    fi
}

handle_grader_error() {
    local frame=0 LINE SUB FILE
    while read LINE SUB FILE < <(caller "$frame"); do
        if [ $frame -eq 0 ]; then
            #echo -e "\n$(tput setaf 1)Error occurred on line ${LINE} in ${FILE}. The failed command was:$(tput sgr 0)"
            #awk '{if(NR==L) print $0}' L=$LINE $FILE
            write_error_json RETTYPE "Error occurred on line ${LINE} in ${FILE}." "$(awk '{if(NR==L) print $0}' L=$LINE $FILE)"
        fi
        ((frame++))
    done
    exit 0
}

run_grader() {
	trap 'handle_grader_error' ERR
    cd $GRADER_DIR
	source ${GRADER_DIR}/grader.sh
    cd $DIR
}

# remove the old error json message
rm -f /home/student/grader/error.json

# get the grader dir and timeout from cmd params
GRADER_DIR=$1
GRADER_TIMEOUT=$2

if [ -z "$1" ]; then
    write_error_json INTERNAL "No grader dir argument given! Exiting..."
    exit 0
fi

if [ -z "$2" ]; then
    echo "No grader timeout argument given! Using default of 15..."
    GRADER_TIMEOUT=15
fi


# check that dir is correct
dir_check_help=$GRADER_DIR
while [ $dir_check_help != "/" ]; do
    echo $dir_check_help
    if [ $dir_check_help == "/home/student/grader" ]; then
        break
    elif [ $dir_check_help == "." ]; then
        write_error_json INTERNAL "Error: $GRADER_DIR is not a subdir of /home/student/grader !"
        exit 1
    fi
dir_check_help=$(dirname $dir_check_help)
done

if [ $dir_check_help == "/" ]; then
    write_error_json INTERNAL "Error: $GRADER_DIR is not a subdir of /home/student/grader !"
    exit 0
fi


# run the grader and give it some time to finish
( run_grader ) & pid=$!
( sleep $GRADER_TIMEOUT && kill -HUP $pid ) 2>/dev/null & watcher=$!
if wait $pid 2>/dev/null; then
    echo "your_command finished with status $?"
    pkill -HUP -P $watcher
    wait $watcher
else
    # the wait returns greater than 128 when killed by signal (SIGHUP)
    if [ $? -gt 128 ]; then
        write_error_json TIMEOUT "Grader timeout after $GRADER_TIMEOUT seconds !"
    fi
fi