#!/bin/bash

_ubuntu_ver=$1
_ubuntu_ver_default=20
_hosted_ubuntu_ver=$(lsb_release -sr 2>/dev/null)
_expat_lib_ver=1.6.11

function warning {
  echo "--WARNING!"
  echo "--$1"
  echo ""
}

if [ -z $_ubuntu_ver ]; then
  _ubuntu_ver=$_ubuntu_ver_default
  warning "Ubuntu version was not specified, $_ubuntu_ver will be used as default"
fi

case $_ubuntu_ver in
  16|18|20)
    _ubuntu_ver=$_ubuntu_ver.04

    case $_ubuntu_ver in
      16)
        _expat_lib_ver=1.6.7;;
      18)
        _expat_lib_ver=1.6.7;;
      *)
        ;;
    esac

    if [ ! -z $_hosted_ubuntu_ver ]; then
      if [ ! $_hosted_ubuntu_ver = $_ubuntu_ver ]; then
        warning "Specified Ubuntu version '$_ubuntu_ver' does not match the hosted Ubuntu version '$_hosted_ubuntu_ver'"
      fi
    else
      warning "Failed to detect hosted Ubuntu version"
    fi

    echo "Ubuntu version: "$_ubuntu_ver;;
  *)
    warning "Specified Ubuntu version '$_ubuntu_ver' is unexpected. Allowed versions: 16, 18, or 20";
    exit 1;;
esac

docker build --build-arg ubuntu_ver=$_ubuntu_ver --build-arg expat_lib_ver=$_expat_lib_ver -f Dockerfile -t atf_worker .
