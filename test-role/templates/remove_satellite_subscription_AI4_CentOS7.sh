#!/bin/bash
# -- remove satellite --

# set a file to catch stdout and stderr
_log_file=/home/svc.ansible/remove_satellite_$(date +%Y-%m-%d_%H-%M-%S)
echo "-- starting Satellite removal on $(hostname) at $(date +%Y/%m/%d_%H:%M:%S) " >> ${_log_file}

echo "   -- list files related to yum configuration " >> ${_log_file}
ls -lR /etc/yum* 2>&1 >> ${_log_file}

echo "   -- look for satellite references in yum configuration since some may need manual cleanup " >> ${_log_file}
grep -r satellite /etc/yum* 2>&1 >> ${_log_file} 

echo "   -- check if subscription manager is installed, if not, no need to try removing it "  >> ${_log_file}
if [ -f /sbin/subscription-manager ]  
then
  echo "   -- checking for running yum hourly and killing it "
  [[ "X$(ps -ef | grep yum | grep -v grep | awk '{ print $2 }')" != "X" ]] && kill -9 $(ps -ef | grep yum | grep -v grep | awk '{ print $2 }') 2>&1 >> ${_log_file}

  echo "   -- clean yum cache " >> ${_log_file}
  yum clean all 2>&1 >> ${_log_file}
  rm -rvf /var/cache/yum/*  >> ${_log_file}

  echo "   -- starting subscription removal "  >> ${_log_file}
  [[ "X$(ps -ef | grep yum | grep -v grep | awk '{ print $2 }')" != "X" ]] && kill -9 $(ps -ef | grep yum | grep -v grep | awk '{ print $2 }') 2>&1 >> ${_log_file}
  subscription-manager remove --all 2>&1 >> ${_log_file}
  subscription-manager clean 2>&1 >> ${_log_file}

  _armedia_katello_rpm=$(rpm -qa | grep katello-ca)
  echo "   -- removing Armedia katello :${_armedia_katello_rpm}: " >> ${_log_file}
  [[ "X${_armedia_katello_rpm}" != "X" ]] && rpm -e ${_armedia_katello_rpm} 2>&1 >> ${_log_file}

  echo "   -- debug - checking subscription manager settings " >> ${_log_file}
  subscription-manager config --list 2>&1 >> ${_log_file}

  echo "   -- removing subscription manager "  >> ${_log_file}
  [[ "X$(ps -ef | grep yum | grep -v grep | awk '{ print $2 }')" != "X" ]] && kill -9 $(ps -ef | grep yum | grep -v grep | awk '{ print $2 }') 2>&1 >> ${_log_file}
  yum remove subscription-manager -y 2>&1 >> ${_log_file}

  echo "   -- cleaning cachle and running yum update "  >> ${_log_file}
  rm -rf /var/cache/yum/* 2>&1 >> ${_log_file} 

  # set other packages to remove as space delimited
  _other_oddballs_to_remove="python2-qpid-proton"
  _other_oddballs_to_remove_rpms=
  echo "   -- checking for ${_other_oddballs_to_remove} since this/these will break updates once yum is configured to pull from the internet " >> ${_log_file} 
  [[ "X${_other_oddballs_to_remove}" != "X" ]] &&  _other_oddballs_to_remove_rpms=$(rpm -qa ${_other_oddballs_to_remove})  2>&1 >> ${_log_file} 
  
  echo "     -- attempting to remove :${_other_oddballs_to_remove_rpms}: " >> ${_log_file} 
  [[ "X${_other_oddballs_to_remove_rpms}" != "X" ]] && rpm -e ${_other_oddballs_to_remove_rpms} 2>&1 >> ${_log_file}  

  echo "   -- look for satellite references leftover in yum configuration since some may need manual cleanup " >> ${_log_file}
  _satellite_references=$(grep -r satellite /etc/yum*)
  #Set the field separator to new line to account for multiple entries
  IFS=$'\n'
  for _item in ${_satellite_references}
  do
    _file=$(echo ${_item} | awk -F: '{print $1}')
    [[ -f ${_file} ]] && sed -i 's/^enabled.*$/enabled=0/g' ${_file} 2>&1 >> ${_log_file} 
    echo "    -- attempting to disable repo for ${_file} based on ${_item}"  >> ${_log_file}
  done

  [[ "X$(ps -ef | grep yum | grep -v grep | awk '{ print $2 }')" != "X" ]] && kill -9 $(ps -ef | grep yum | grep -v grep | awk '{ print $2 }') 2>&1 >> ${_log_file}
  yum update -y 2>&1 >> ${_log_file}
else
  echo "     -- subscription manager is not installed "  >> ${_log_file}
fi
echo "-- finished Satellite removal on $(hostname) at $(date +%Y/%m/%d_%H:%M:%S) " >> ${_log_file}
