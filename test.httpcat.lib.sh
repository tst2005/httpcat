
. ./httpcat.lib.sh
export SECRET=$(newsecret)
#export HTTPCAT_DEBUG=true

# HTTPCAT_HOST=localhost
# HTTPCAT_PORT=18081
export HTTPCAT_PORT=18324

( httpcat | md5sum ) &
sleep 1

f=big.bin
base64 -d big.base64 > "$f"
md5sum "$f"
SECRET="$SECRET" httpcat "$f"
