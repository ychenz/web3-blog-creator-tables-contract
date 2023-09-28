# Kill all process that use port 8080 which prevents the tableland node from running
for pid in $(sudo netstat -nuptl|grep 8080| awk '{print $NF}'|cut -d/ -f1); do sudo kill $pid; done
