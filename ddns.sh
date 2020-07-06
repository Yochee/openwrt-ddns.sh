Domain="domain.com"
SubDomain="www"
AccessId="****************"
AccessSecret="******************************"
TTL="600"

urlencode() {
    out=""
    while read -n1 c
    do
        case $c in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

enc() {
    echo -n "$1" | urlencode
}

send_request() {
    local args="AccessKeyId=$AccessId&Action=$1&Format=json&$2&Version=2015-01-09"
    local hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$AccessSecret&" -binary | openssl base64)
    curl -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
}

query_record() {
    send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$Timestamp&SignatureVersion=1.0&SubDomain=$SubDomain.$Domain&Timestamp=$Timestamp"
}

update_record() {
    send_request "UpdateDomainRecord" "RR=$SubDomain&RecordId=$RecordId&SignatureMethod=HMAC-SHA1&SignatureNonce=$Timestamp&SignatureVersion=1.0&TTL=$TTL&Timestamp=$Timestamp&Type=A&Value=$LocalIP"
}

Timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
LocalIP=`curl -s whatismyip.akamai.com 2>&1`
Record=`query_record`
RecordId=`echo $Record | grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'`
RecordIP=`echo $Record | grep -Eo '"Value":"(\.|[0-9])+"' | cut -d':' -f2 | tr -d '"'`

echo "Local IP: $LocalIP"
echo "DNS record: $RecordIP"
echo "Record Id: $RecordId"

if [ "${LocalIP}" != "${RecordIP}" ]; then
    Result=`update_record | grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'`
    if [ "${Result}" = "" ]; then
        echo "Error"
        exit 1
    else
        echo "success"
    fi
else
    echo -e "Record already up to date"
fi
exit 0
