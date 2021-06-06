cat <<EOF > /root/sh/sip_ws_cnt.sh
#!/bin/sh
LINE="------------------------------------------"
while [ true  ]
do
echo \${LINE}
echo "Nginx : "\`netstat -anp | grep nginx | grep ESTABLISHED | grep :443 | wc -l\`
echo "Asterisk : "\`netstat -anp | grep 127.0.0.1:8088 | grep ESTABLISHED | grep asterisk | wc -l\`
echo \${LINE}
sleep 3
done
exit
EOF
chmod 500 /root/sh/sip_ws_cnt.sh
ln -s /root/sh/sip_ws_cnt.sh /usr/bin/sip_ws_cnt

cat <<EOF > /root/sh/restart_asterisk.sh
#!/bin/bash
LINE="------------------------------------------------"
SLACK_URL="https://hooks.slack.com/services/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"
ARG="\$1"
DATE=\`date\`
HARD="-hard"
TEXT=""
echo \${LINE}
TEXT=\$TEXT"\\n"\${LINE}
OLD_PID_STR=\`netstat -anp | grep LISTEN | grep asterisk | grep :8088 | awk '{print \$7}'\`
if [ "\${OLD_PID_STR}" != "" ]; then
  ACTIVE_CHANNELS_CNT=\`/usr/bin/asterisk -rx "core show channels" | grep "active channel" | awk '{print \$1}'\`
else
  ACTIVE_CHANNELS_CNT=0
fi
echo \${DATE}
echo \${LINE}
echo "Asterisk has \${ACTIVE_CHANNELS_CNT} active channels."
TEXT=\$TEXT"\\n*\${DATE}*"
TEXT=\$TEXT"\\n"\${LINE}
TEXT=\$TEXT"\\n""Asterisk has \${ACTIVE_CHANNELS_CNT} active channels."
if [ "\${ARG}" = "\${HARD}"  ]; then
  echo ">> Forcibly restart Asterisk with option '-hard'. <<"
  TEXT=\$TEXT"\\n""[ Forcibly restart Asterisk with option '-hard'. ]"
fi
if [ \${ACTIVE_CHANNELS_CNT} = 0 -o "\${ARG}" = "\${HARD}" ]; then
  HOSTNAME=\`hostname\`
  TEXT=\$TEXT"\\n \\\`Asterisk is dead now (\${HOSTNAME}).\\\` "
  TEXT=\$TEXT"\\n""\${HOSTNAME}"
  echo "OLD_PID/asterisk = \${OLD_PID_STR}"
  echo "Stopping Asterisk..."
  TEXT=\$TEXT"\\n""OLD_PID/asterisk = \${OLD_PID_STR}"
  TEXT=\$TEXT"\\n""Stopping Asterisk..."
  systemctl stop asterisk
  sleep 1
  echo "Starting Asterisk..."
  TEXT=\$TEXT"\\n""Starting Asterisk..."
  systemctl start asterisk
  sleep 3
  /usr/bin/asterisk -rx "logger reload"
  NEW_PID_STR=\`netstat -anp | grep LISTEN | grep asterisk | grep :8088 | awk '{print \$7}'\`
  echo "NEW_PID/asterisk = \${NEW_PID_STR}"
  echo "...done!"
  echo \${LINE}
  TEXT=\$TEXT"\\n""NEW_PID/asterisk = \${NEW_PID_STR}"
  TEXT=\$TEXT"\\n""...done!"
  TEXT=\$TEXT"\\n"\${LINE}
  /usr/bin/curl -X POST "\${SLACK_URL}" -d "payload={\\"username\\": \\"pbx-alert@\${HOSTNAME}\\",\\"text\\": \\"\${TEXT}\\",\\"icon_emoji\\": \\":exclamation:\\"}"
else
  echo "Sorry! Try again when Asterisk has no active channels!"
  echo \${LINE}
  TEXT=\$TEXT"\\n"\${LINE}
fi
exit 0
EOF
chmod 500 /root/sh/restart_asterisk.sh
ln -s /root/sh/restart_asterisk.sh /usr/bin/restart_asterisk

cat <<EOF > /root/sh/channels.sh
#!/bin/sh
LINE="-----------------------------------------"
if [ "\$1" != "" ]; then
  while true;
  do
    echo \${LINE}
    /usr/bin/asterisk -rx "core show channels" | grep active;
    echo \${LINE}
    sleep \$1s;
  done
else
  echo "No args!!"
fi
exit 0
EOF
chmod 500 /root/sh/channels.sh
ln -s /root/sh/channels.sh /usr/bin/channels

cat <<EOF > /root/sh/channel.sh
#!/bin/sh
/usr/bin/asterisk -rx "core show channels" | grep active;
exit 0
EOF
chmod 500 /root/sh/channel.sh
ln -s /root/sh/channel.sh /usr/bin/channel

cat <<EOF > /root/sh/register_count.sh
#!/bin/sh
LINE=------------------------------------------
  while true;
  do
    echo \${LINE}
    /usr/bin/asterisk -rx "pjsip show contacts" | grep "Objects found" | awk '{print "> Register Contacts : "\$3}'
    echo \${LINE}
    sleep 5;
  done
exit 0
EOF
chmod 500 /root/sh/register_count.sh
ln -s /root/sh/register_count.sh /usr/bin/register_count

cat <<EOF > /root/sh/current_register_count.sh
#!/bin/bash
COUNT=\`/usr/bin/asterisk -rx "pjsip show contacts" | grep "Objects found" | awk '{print \$3}'\`
if [ "\${COUNT}" != "" ]; then
  echo \${COUNT}
else
  echo 0
fi
exit 0
EOF
chmod 500 /root/sh/current_register_count.sh
chown root. /root/sh/current_register_count.sh
ln -s /root/sh/current_register_count.sh /usr/bin/current_register_count

cat <<EOF > /root/sh/active_call.sh
#!/bin/bash
/usr/bin/asterisk -rx "core show channels" | grep "active call" | awk '{print \$1}'
exit 0
EOF

chmod 500 /root/sh/active_call.sh
chown root. /root/sh/active_call.sh
ln -s /root/sh/active_call.sh /usr/bin/active_call

cat <<EOF > /root/sh/active_channel.sh
#!/bin/bash
/usr/bin/asterisk -rx "core show channels" | grep "active channel" | awk '{print \$1}'
exit 0
EOF

chmod 500 /root/sh/active_channel.sh
chown root. /root/sh/active_channel.sh
ln -s /root/sh/active_channel.sh /usr/bin/active_channel

cat <<EOF > /root/sh/memories.sh
#!/bin/bash
PS=\`ps -aux\`
TOMCAT_PID=\`echo "\${PS}" | grep /usr/local/tomcat8 | grep -v grep | awk '{print \$2}'\`
GOEMON_PID=\`echo "\${PS}" | grep /usr/local/goemon/comdesk_bl.jar | grep -v grep | grep -v sudo | awk '{print \$2}'\`
ASTERISK_PID=\`echo "\${PS}" | grep /usr/local/asterisk/sbin/asterisk | grep -v grep | awk '{print \$2}'\`
TURNSERVER_PID=\`echo "\${PS}" | grep /usr/local/bin/turnserver | grep senoway:yu51043chie3 | awk '{print \$2}'\`
SMEM=\`/usr/bin/smem\`
TOMCAT_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"
GOEMON_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"
ASTERISK_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"
TURNSERVER_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"

if [ "\${TOMCAT_PID}" != "" ]; then
  TOMCAT_JSON=\`echo "\${SMEM}" | grep /usr/bin/java | grep \${TOMCAT_PID} | awk '{print "{ \"rss\": \""\$8"\", \"pss\": \""\$7"\", \"uss\": \""\$6"\" }"}' \`
fi
if [ "\${GOEMON_PID}" != "" ]; then
  GOEMON_JSON=\`echo "\${SMEM}" | grep /usr/bin/java | grep \${GOEMON_PID} | awk '{print "{ \"rss\": \""\$9"\", \"pss\": \""\$8"\", \"uss\": \""\$7"\" }"}' \`
fi
if [ "\${ASTERISK_PID}" != "" ]; then
  ASTERISK_JSON=\`echo "\${SMEM}" | grep /usr/local/asterisk | grep \${ASTERISK_PID} | awk '{print "{ \"rss\": \""\$7"\", \"pss\": \""\$6"\", \"uss\": \""\$5"\" }"}' \`
fi
if [ "\${TURNSERVER_PID}" != "" ]; then
 TURNSERVER_JSON=\`echo "\${SMEM}" | grep /usr/local/bin/turnserver | grep \${TURNSERVER_PID} | awk '{print "{ \"rss\": \""\$8"\", \"pss\": \""\$7"\", \"uss\": \""\$6"\" }"}' \`
fi

echo "{"
echo "  \"tomcat\": \${TOMCAT_JSON},"
echo "  \"goemon\": \${GOEMON_JSON},"
echo "  \"asterisk\": \${ASTERISK_JSON},"
echo "  \"turnserver\": \${TURNSERVER_JSON}"
echo "}"

exit 0
EOF

chmod 500 /root/sh/memories.sh
chown root. /root/sh/memories.sh
ln -s /root/sh/memories.sh /usr/bin/memories

cat <<EOF > /root/sh/cpus.sh
#!/bin/bash
PS=\`ps -aux\`
TOMCAT_PID=\`echo "\${PS}" | grep /usr/local/tomcat8 | grep -v grep | awk '{print \$2}'\`
GOEMON_PID=\`echo "\${PS}" | grep /usr/local/goemon/comdesk_bl.jar | grep -v grep | grep -v sudo | awk '{print \$2}'\`
ASTERISK_PID=\`echo "\${PS}" | grep /usr/local/asterisk/sbin/asterisk | grep -v grep | awk '{print \$2}'\`
TURNSERVER_PID=\`echo "\${PS}" | grep /usr/local/bin/turnserver | grep senoway:yu51043chie3 | awk '{print \$2}'\`
TOMCAT_CPU=0.00
GOEMON_CPU=0.00
ASTERISK_CPU=0.00
TURNSERVER_CPU=0.00

if [ "\${TOMCAT_PID}" != "" ]; then
  TOMCAT_CPU=\`/usr/bin/pidstat -p \${TOMCAT_PID} | grep java | awk '{print \$8}'\`
fi
if [ "\${GOEMON_PID}" != "" ]; then
  GOEMON_CPU=\`/usr/bin/pidstat -p \${GOEMON_PID} | grep java | awk '{print \$8}'\`
fi
if [ "\${ASTERISK_PID}" != "" ]; then
  ASTERISK_CPU=\`/usr/bin/pidstat -p \${ASTERISK_PID} | grep asterisk | awk '{print \$8}'\`
fi
if [ "\${TURNSERVER_PID}" != "" ]; then
 TURNSERVER_CPU=\`/usr/bin/pidstat -p \${TURNSERVER_PID} | grep turnserver | awk '{print \$8}'\`
fi

echo "{"
echo "  \"tomcat\": \"\${TOMCAT_CPU}\","
echo "  \"goemon\": \"\${GOEMON_CPU}\","
echo "  \"asterisk\": \"\${ASTERISK_CPU}\","
echo "  \"turnserver\": \"\${TURNSERVER_CPU}\""
echo "}"

exit 0
EOF

chmod 500 /root/sh/cpus.sh
chown root. /root/sh/cpus.sh
ln -s /root/sh/cpus.sh /usr/bin/cpus
