
newsecret() {
	shuf -i 0-9999 -n 1
}
httpcat() {
	# http_get
	if [ $# -eq 0 ] || [ "$1" = "-" ]; then
		local port="${HTTPCAT_PORT:-18081}"

# code is a template with all ' replaced by `
code='
	if [ $# -ne 0 ]; then
		exit 123
	fi
	if [ -s "$TMPFILE" ]; then
		echo >&2 "FATAL: file is not empty"
		exit 10
	fi

	httpreply() { printf `%s\r\n` "$@"; }

	read -r line
	case "$line" in
		(`GET `*|`PUT `*|`POST `*) ;;
		(*) exit 2 ;;
	esac
	[ -z "$HTTPCAT_DEBUG" ] || echo >&2 "+$line"
	case "$line" in
		(*` /`"$SECRET"` HTTP/`*) ;;
		(*)
			echo >&2 "# a client ask with a wrong secret"
			httpreply `Status: 403 Forbidden` ``
			exit 2
		;;
	esac

	len=``
	while IFS="$(printf `\r\n`)" read -r line;do
		[ -n "$line" ] || break
		[ -z "$HTTPCAT_DEBUG" ] || echo >&2 "+$line"
		case "$(printf `%s` "$line" | tr `A-Z` `a-z`)" in
			(`content-length: `[0-9]*) len="${line#*: }" ;;
			(`x-md5sum: `????????????????????????????????) x_md5sum="${line#*: }" ;;
		esac
	done

	httpreply `Status: 200 OK` `Connection: closed` ``

	if ! dd status=none ibs=1 ${len:+count=$len} "of=$TMPFILE"; then
		echo >&2 "FATAL: dd error ?!"
		exit 10
	fi
	if [ -n "$x_md5sum" ]; then
		sum="$(md5sum "$TMPFILE")"
		sum="${sum%% *}"
		if [ "$sum" != "$x_md5sum" ]; then
			echo >&2 "FATAL: checksum mismatch ($sum VS $x_md5sum)"
			exit 10
		else
			[ -z "$HTTPCAT_DEBUG" ] || echo >&2 "OK: checksum match"
		fi 
	fi
	exit 0
'
# end of template
		local TMPFILE="$(mktemp)"
		echo >&2 "http://localhost:${port:-18081}/$SECRET"

		local ret=0
		local retry=${HTTPCAT_MAXRETRY:-60}
		while [ $retry -gt 0 ]; do
			TMPFILE="$TMPFILE" SECRET="$SECRET" \
			nc -l -p ${port:-18081} -c "$(printf '%s\n' "$code"|tr '`' "'")"
			ret=$?
			case "$ret" in
				(1|2)	retry=$(($retry-1));
					[ -z "$HTTPCAT_DEBUG" ] || echo >&2 "restart ($retry)";
					continue
				;;
				(0) cat -- "$TMPFILE" ;;
				#(10) is fatal error
			esac
			break
		done
		rm -f -- "$TMPFILE"
		return $ret
	fi

	# http_send
	if [ $# -lt 1 ] || [ ! -f "$1" ]; then
	        echo >&2 "Usage: httpcat <file>"
        	return 1
	fi
	local host="${HTTPCAT_HOST:-localhost}"
	local port="${HTTPCAT_PORT:-18081}"
	x_md5sum="$(md5sum "$1")"
	x_md5sum="${x_md5sum%% *}"
	(
		len=$(stat -c %s "$1")
		printf '%s\r\n' \
			"PUT /${SECRET} HTTP/1.0" \
			"Host: ${host}:${port}" \
			"User-Agent: httpcat" \
			'Accept: */*' \
			"X-Md5sum: $x_md5sum" \
			"Content-Length: $len" \
			''
		cat -- "$1"
	) | nc ${host} ${port} |tr '\r' '\n' | grep -qi '^Status: 200 OK'
	#curl -s --http1.0 --upload-file "$1" http://${host}:${port}/${SECRET} >/dev/null
	return $?
}

