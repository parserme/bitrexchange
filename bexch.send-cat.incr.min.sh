#!/bin/bash
#
# bitrexchange - bitrix exchange
# Скрипт стандартного обмена 1C и Битрикс по стандарту CommerceML
# Инкрементальная выгрузка XML файлов каталога import и offers
#
set -e

cd $(dirname $0)
cdir=$(pwd)"/"
#
remote_dir="/mnt/localwinserver_fs/import/webdata/"
zip_fname="catalogue.zip"
xml_files="import0_1.xml offers0_1.xml"
email1="admin@yourinternetshop.com";
email2="alert@yourinternetshop.com";

ctime=$(date +%Y-%m-%d-%H%M)

chan=$(grep  -e "СодержитТолькоИзменения=\"true" ${remote_dir}*.xml | wc -l);if test "$chan" != "2"; then echo "Error: XMLs are not in 'changes only' mode or file(s) are missing\r\n"; mail -s "Загрузка цен" -a "From: bitrexchange <${email1}>" $email1,$email2 <<< "Не прошла загрузка цен на сайт."; exit 1; else echo "OK: Format of XMLs are 'changes only'";fi
if [ -f $zip_fname ]; then mv $zip_fname "${zip_fname}.${ctime}"; fi
/usr/bin/zip -9j "$zip_fname" ${remote_dir}*.xml

##########################################################################

headers="--header=\"User-Agent: 1C+Enterprise/8.2\" --header=\"Accept-Encoding: deflate\""
login="import"
password="yourpasswordonbitrix"
baseurl="http://yourinternetshop.com/bitrix/admin/1c_exchange.php"

##########################################################################
ret_line=$( wget $headers --user=${login} --password=${password} --auth-no-challenge -O - -q "${baseurl}?type=sale&mode=checkauth" )
read -a ret_ar <<< $ret_line
if [ ${ret_ar[0]} != "success" ]; then echo "Login error\r\n"; exit -1; fi
sessvar=${ret_ar[1]}
sessid=${ret_ar[2]}
echo sessid=$sessid
ret=$(wget $headers --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=init"); echo $ret
ret=$(wget $headers --post-file ${zip_fname} --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=file&filename=import.zip"); echo $ret
for fname in $xml_files; do
st="progress"; while [ "$st" = "progress" ]; do ret=$(wget $headers --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=import&filename=${fname}"); st=$( <<< "$ret" head -n1 | cut -c1-8); echo "$ret" | iconv -f cp1251 -t utf-8; done
done
