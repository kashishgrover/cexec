#!/bin/bash -e

export INSTALL_REQS=false
readonly VIRTUALENV_VERSION=1.11.4
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly VIRTUALENV_DIR="$HOME/shippable_ve"
readonly ARTIFACTS_DIR="/shippableci"

## If this script is invoked with 'install' argument
## then set the INSTALL_REQS flag to true
if [[ $# > 0 ]]; then
  if [[ "$1" == "install" ]]; then
    export INSTALL_REQS=true
  else
    export INSTALL_REQS=false
  fi
fi

update_dir() {
  cd $PROGDIR
}

update_perms() {
  SUDO=`which sudo`
  $SUDO mkdir -p /home/shippable/build/logs
  $SUDO mkdir -p /shippableci
  $SUDO chown -R $USER:$USER /home/shippable/build/logs
  $SUDO chown -R $USER:$USER /home/shippable/build
}

install_core_binaries() {
  # Set up the virtual environment for the worker
  PIP=`which pip`
  GIT=`which git`

  if [ "$PIP" == "" ] || [ "$GIT" == "" ]; then
    echo "Installing python-pip and git"
    $SUDO apt-get update && $SUDO apt-get install -y python-pip ssh git-core
    pip install -I virtualenv==$VIRTUALENV_VERSION
  fi;
}

install_virtualenv() {
  local PIP=`which pip`
  local virtualenv_filename="virtualenv-$VIRTUALENV_VERSION.tar.gz"
  {
    echo "****** Installing virtualenv $VIRTUALENV_VERSION ********"
    if [[ ! -z "$SUDO" ]]; then
      $SUDO $PIP install -I $PROGDIR/packages/$virtualenv_filename
    else
      $PIP install -I $PROGDIR/packages/$virtualenv_filename
    fi
  } || {
    wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
    python get-pip.py
    if [[ ! -z "$SUDO" ]]; then
      $SUDO $PIP install -I virtualenv==$VIRTUALENV_VERSION
    else
      $PIP install -I virtualenv==$VIRTUALENV_VERSION
    fi
  }
}


install_packages() {
  echo "******** Installing requirements ************"
  if [[ $INSTALL_REQS == true ]]; then
    virtualenv -p `which python2.7` $VIRTUALENV_DIR
    source $VIRTUALENV_DIR/bin/activate
    pip install -I -r requirements.txt
  else
    if [ -f /deps_updated.txt ]; then
      echo "Build dependencies already updated..."
    else
      echo "Build dependencies not updated, installing..."
      pip install -I -r requirements.txt
    fi
  fi
}

update_ssh_config() {
  mkdir -p $HOME/.ssh
  touch $HOME/.ssh/config
  # Turn off strict host key checking
  echo -e "\nHost *\n\tStrictHostKeyChecking no" >> $HOME/.ssh/config
}

update_build_dirs() {
  mkdir -p $ARTIFACTS_DIR
}

run_build() {
  python main.py
}

main() {
  update_dir
  update_perms
  install_core_binaries
  install_virtualenv
  install_packages
  update_ssh_config
  update_build_dirs
  run_build
}

main
