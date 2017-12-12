
. ./httpcat.lib.sh
#export HTTPCAT_DEBUG=true
# HTTPCAT_HOST=localhost
# HTTPCAT_PORT=18081
export HTTPCAT_HOST=localhost
export HTTPCAT_PORT=18123

# define a secret
export SECRET=$(newsecret)

f=big.bin
[ -f "$f" ] || base64 -d big.base64 > "$f"

(
# show the original file
echo "C: original: $(md5sum "$f")"

sleep 1

# try with a wrong secret
( SECRET="wrongsecret" httpcat "$f" )
( SECRET="anothertry" httpcat "$f" )

# send the file
SECRET="$SECRET" httpcat "$f"

) &

#sleep 1

# launch the serveur and pipe the result into md5sum
HTTPCAT_DEBUG=true httpcat | md5sum | sed 's,^,S: ,g'

# it will be receive by the server side and calculate the checksum
