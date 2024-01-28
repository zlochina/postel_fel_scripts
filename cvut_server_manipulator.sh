#!/bin/bash

MANUAL="
SOME_MANUAL
"

# function exectution of the script
function execute() {
  SSH_COMMAND_WITH_SCRIPT="$SSH_COMMAND \"$SERVER_SCRIPT_TO_BE_EXECUTED\""
  echo "[INFO]: Logging in to $SERVER_IP and executing script:"
  echo "$SERVER_SCRIPT_TO_BE_EXECUTED" | tr ';' '\n' | sed 's/^/❯ /'
  echo "$SEPERATOR"
  eval "$SSH_COMMAND_WITH_SCRIPT"
}

function build_script_variable() {
  echo "[INFO]: Building script variable"
  # TODO build next variable
  SOME_SCRIPT="dsjalkdjsa"
}

function check_inital_variables() {
  echo "[INFO]: Checking if initial variables are set"
  if [ ! -e "$ZIP_PROJECT" ]; then
    echo "[ERROR]: Variable ZIP_PROJECT is not set"
    exit 1
  fi
}

# function to send the project
function send_project() {
  echo "[INFO]: Sending project to $SERVER_IP..."
  eval "$SCP_COMMAND \"$ZIP_PROJECT\" \"$SERVER_IP:~/$WORKING_DIR/$TMP\""
  RETURN_VALUE=`echo $?`
  if [ "$RETURN_VALUE" == 0 ]; then
  echo "[INFO]: Project is sent"
  else
  echo "[ERROR]: Project was not sent with return value $RETURN_VALUE"
  fi
}

# function to "!make" the C package and run it
function make_and_run() {
  # check if initial variables are okay

  LOCAL_TMP_DIRECTORY="project_tmp"
  if [ -e "$LOCAL_TMP_DIRECTORY/" ] && [ -d "$LOCAL_TMP_DIRECTORY" ]; then
    LOCAL_TMP_DIRECTORY="project_tmp_$RANDOM"
  fi

  # Check build
  echo "[INFO]: Check build."
  mkdir "$LOCAL_TMP_DIRECTORY"
  cp "$ZIP_PROJECT" "$LOCAL_TMP_DIRECTORY/$ZIP_PROJECT"
  cd "$LOCAL_TMP_DIRECTORY"
  unzip "$ZIP_PROJECT"

  # check for Makefile
  if [ -e "Makefile" ]; then
    echo "[INFO]: Makefile exists... OK"
  else
    echo "[ERROR]: Project does not contain Makefile, which does not allow manipulator to proceed."
    cd ..
    rm -rf "$LOCAL_TMP_DIRECTORY"
    exit 1
  fi

  # find initial set of executables in the directory
  initial_executables=$(find_executables)

  # proceed
  make
  BUILD_RETURN_VALUE="$?"

  # find executables again after running `make`
  new_executables=$(find_executables)

  # Compare initial and new executables to find newly created ones
  newly_created_executables=$(comm -23 <(echo "$new_executables" | sort) <(echo "$initial_executables" | sort))

  cd ..
  echo "[INFO]: Deleting tmp directory"
  rm -rf "$LOCAL_TMP_DIRECTORY"

  if [ "$BUILD_RETURN_VALUE" -ne 0 ]; then
    # build was failed
    echo "[ERROR]: Project was failed to build. Please check for any errors."
    exit 1
  else
    echo "[INFO]: Project was built with Makefile... OK"
  fi

  echo "[INFO]: Now printing executables produced by Makefile"
  echo "$newly_created_executables"

  # send Zip project to remote server
  send_project

  # TODO update SERVER_SCRIPT_TO_BE_EXECUTED
  # - need to run executable
  PROJECT_FILENAME=`echo "$ZIP_PROJECT" | eval ${PROJECT_FILENAME_SED}`
  SERVER_SCRIPT_TO_BE_EXECUTED="cd $WORKING_DIR/$TMP;rm -rf \"$PROJECT_FILENAME\";mkdir \"$PROJECT_FILENAME\";mv $ZIP_PROJECT $PROJECT_FILENAME/$ZIP_PROJECT;cd $PROJECT_FILENAME;unzip $ZIP_PROJECT;make;"

  # TODO find executable and run it

}

function valgrind_package() {
  echo "valgrind run"

}

# function to just save package to some path
function send_and_save_to_path() {
  AIMED_PATH = "$1"
}

# Function to find executables in the current directory
find_executables() {
    ls -l | grep "^-..x" | awk '{print $NF}'
}

# function to create architecture for this script to work fine
function init_architecture_on_server_side() {
  echo "[INFO]: Initialised building architecture on server side."
  SERVER_SCRIPT_TO_BE_EXECUTED="cd ~;mkdir $WORKING_DIR;cd $WORKING_DIR;mkdir $TMP;mkdir $SCRIPT_DIR"
  execute
}

# Description of the architecture:
# $TMP = path_to_tmp_dir , where would be stored and retrieved packages
# $SCRIPT_DIR = path_to_scripts_dir, where will be stored packages and projects, which were designed to be saved on the server
#
WORKING_DIR="Remote_work"
TMP="tmp"
SCRIPT_DIR="projects"
# Definitions of variables
SEPERATOR=">----------<"
LOCAL_PATH_TO_SSH_KEYS="/Users/zlochinus/.ssh/cvut_server"
USERNAME="zlochvla"

SERVER_IP="${USERNAME}@postel.felk.cvut.cz"
SERVER_SCRIPT_TO_BE_EXECUTED="" # script which will be executed on the server
SSH_COMMAND="ssh -i \"$LOCAL_PATH_TO_SSH_KEYS\" \"$SERVER_IP\""
SCP_COMMAND="scp -i \"$LOCAL_PATH_TO_SSH_KEYS\" "

ZIP_PROJECT=""
# TODO PROJECT_FILENAME sed todo + need to move this to some option processing
PROJECT_FILENAME_SED="sed -n '/\.zip\$/s/\(.*\)\.zip\$/\1/p'"


# debug TODO delete
SOME_SCRIPT="pwd"
SSH_COMMAND_WITH_SCRIPT="$SSH_COMMAND \"$SOME_SCRIPT\""

# flags
FLAG_SAVE=0
FLAG_VALGRIND=0
FLAG_MAKE=0
FLAG_SEND=0
FLAG_SIMULTANEOURS_LOGIN=0


# MAIN flow
while getopts ":hsmvdp:itl" opt; do
  case $opt in
    d)
      eval "$ZIP_PROJECT"
      exit 3
      ;;
    p)
      ZIP_PROJECT="$OPTARG"
      ;;
    i) init_architecture_on_server_side
      exit 0
      ;;
    s) FLAG_SEND=1
      ;;
    t) FLAG_SIMULTANEOURS_LOGIN=1
      ;;
    l)
      eval "$SSH_COMMAND"
      exit 0
      ;;
    # s) echo "Saving to path \"$OPTARG\""
    #   FLAG_SAVE=1
    #   ;;
    m) #echo "Making and running with additional argument $OPTARG"
      #MAIN_ARGUMENTS="$OPTARG"
      FLAG_MAKE=1
      ;;
    v) echo "Valgrinding the project"
      FLAG_VALGRIND=1
      ;;
    h) echo "$MANUAL"
      exit 0
      ;;
    ?) echo "Invalid flag -$OPTARG was provided"
      echo "$MANUAL"
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))


# NON-working function
# build_script_variable
# test building project on local machine, send it to the remote machine and build there
if [ "$FLAG_MAKE" -eq 1 ]; then
  check_inital_variables
  make_and_run
  execute
  # TODO replace with adding -t flag to $SSH_COMMAND
  if [ "$FLAG_SIMULTANEOURS_LOGIN" -eq 1 ]; then
    eval "$SSH_COMMAND"
  fi
  exit 0
fi

if [ "$FLAG_SEND" -eq 1 ]; then
  check_inital_variables
  send_project
  if [ "$FLAG_SIMULTANEOURS_LOGIN" -eq 1 ]; then
    eval "$SSH_COMMAND"
  fi
  exit 0
fi

# otherwise
echo "[INFO]: Nothing was executed"
exit 1
