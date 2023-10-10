cat <<EOF > /root/sh/restart_asterisk.sh
#!/bin/bash
LINE="------------------------------------------------"
SLACK_URL="https://hooks.slack.com/services/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"
ARG1="\$1"
ARG2="\$2"
DATE=\`date\`
HARD="-hard"
NO_ALERT="-noalert"
TEXT=""
echo \${LINE}
TEXT=\$TEXT"\\n"\${LINE}
OLD_PID_STR=\`netstat -anp | grep LISTEN | grep asterisk | grep :8088 | awk '{print \$7}'\`
if [ "\${OLD_PID_STR}" != "" ]; then
  ACTIVE_CHANNELS_CNT=\`/usr/local/asterisk/sbin/asterisk -rx "core show channels" | grep "active channel" | awk '{print \$1}'\`
else
  ACTIVE_CHANNELS_CNT=0
fi
echo \${DATE}
echo \${LINE}
echo "Asterisk has \${ACTIVE_CHANNELS_CNT} active channels."
TEXT=\$TEXT"\\n*\${DATE}*"
TEXT=\$TEXT"\\n"\${LINE}
TEXT=\$TEXT"\\n""Asterisk has \${ACTIVE_CHANNELS_CNT} active channels."
if [ "\${ARG1}" = "\${HARD}"  ]; then
  echo ">> Forcibly restart Asterisk with option '-hard'. <<"
  TEXT=\$TEXT"\\n""[ Forcibly restart Asterisk with option '-hard'. ]"
fi
if [ \${ACTIVE_CHANNELS_CNT} = 0 -o "\${ARG1}" = "\${HARD}" ]; then
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
  /usr/local/asterisk/sbin/asterisk -rx "logger reload"
  NEW_PID_STR=\`netstat -anp | grep LISTEN | grep asterisk | grep :8088 | awk '{print \$7}'\`
  echo "NEW_PID/asterisk = \${NEW_PID_STR}"
  echo "...done!"
  echo \${LINE}
  TEXT=\$TEXT"\\n""NEW_PID/asterisk = \${NEW_PID_STR}"
  TEXT=\$TEXT"\\n""...done!"
  TEXT=\$TEXT"\\n"\${LINE}
  if [ "\${ARG2}" != "\${NO_ALERT}" ];then
    /usr/bin/curl -X POST "\${SLACK_URL}" -d "payload={\\"username\\": \\"pbx-alert@\${HOSTNAME}\\",\\"text\\": \\"\${TEXT}\\",\\"icon_emoji\\": \\":exclamation:\\"}"
  fi
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
    /usr/local/asterisk/sbin/asterisk -rx "core show channels" | grep active;
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
/usr/local/asterisk/sbin/asterisk -rx "core show channels" | grep active;
exit 0
EOF
chmod 500 /root/sh/channel.sh
ln -s /root/sh/channel.sh /usr/bin/channel

cat <<EOF > /root/sh/active_call.sh
#!/bin/bash
/usr/local/asterisk/sbin/asterisk -rx "core show channels" | grep "active call" | awk '{print \$1}'
exit 0
EOF

chmod 500 /root/sh/active_call.sh
chown root. /root/sh/active_call.sh
ln -s /root/sh/active_call.sh /usr/bin/active_call

cat <<EOF > /root/sh/active_channel.sh
#!/bin/bash
/usr/local/asterisk/sbin/asterisk -rx "core show channels" | grep "active channel" | awk '{print \$1}'
exit 0
EOF

chmod 500 /root/sh/active_channel.sh
chown root. /root/sh/active_channel.sh
ln -s /root/sh/active_channel.sh /usr/bin/active_channel

cat <<EOF > /root/sh/memories.sh
#!/bin/bash
PS=\`ps -aux\`
TOMCAT_PID=\`echo "\${PS}" | grep /usr/local/tomcat8 | grep -v grep | awk '{print \$2}'\`
GOEMON_PID=\`echo "\${PS}" | grep /usr/local/goemon/mesh_bl.jar | grep -v grep | grep -v sudo | awk '{print \$2}'\`
ASTERISK_PID=\`echo "\${PS}" | grep /usr/local/asterisk/sbin/asterisk | grep -v grep | awk '{print \$2}'\`
SMEM=\`/usr/bin/smem\`
TOMCAT_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"
GOEMON_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"
ASTERISK_JSON="{ \"rss\": \"0\", \"pss\": \"0\", \"uss\": \"0\" }"

if [ "\${TOMCAT_PID}" != "" ]; then
  TOMCAT_JSON=\`echo "\${SMEM}" | grep /usr/bin/java | grep \${TOMCAT_PID} | awk '{print "{ \"rss\": \""\$8"\", \"pss\": \""\$7"\", \"uss\": \""\$6"\" }"}' \`
fi
if [ "\${GOEMON_PID}" != "" ]; then
  GOEMON_JSON=\`echo "\${SMEM}" | grep /usr/bin/java | grep \${GOEMON_PID} | awk '{print "{ \"rss\": \""\$9"\", \"pss\": \""\$8"\", \"uss\": \""\$7"\" }"}' \`
fi
if [ "\${ASTERISK_PID}" != "" ]; then
  ASTERISK_JSON=\`echo "\${SMEM}" | grep /usr/local/asterisk | grep \${ASTERISK_PID} | awk '{print "{ \"rss\": \""\$7"\", \"pss\": \""\$6"\", \"uss\": \""\$5"\" }"}' \`
fi

echo "{"
echo "  \"tomcat\": \${TOMCAT_JSON},"
echo "  \"goemon\": \${GOEMON_JSON},"
echo "  \"asterisk\": \${ASTERISK_JSON}"
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
GOEMON_PID=\`echo "\${PS}" | grep /usr/local/goemon/mesh_bl.jar | grep -v grep | grep -v sudo | awk '{print \$2}'\`
ASTERISK_PID=\`echo "\${PS}" | grep /usr/local/asterisk/sbin/asterisk | grep -v grep | awk '{print \$2}'\`
TOMCAT_CPU=0.00
GOEMON_CPU=0.00
ASTERISK_CPU=0.00

if [ "\${TOMCAT_PID}" != "" ]; then
  TOMCAT_CPU=\`/usr/bin/pidstat -p \${TOMCAT_PID} | grep java | awk '{print \$8}'\`
fi
if [ "\${GOEMON_PID}" != "" ]; then
  GOEMON_CPU=\`/usr/bin/pidstat -p \${GOEMON_PID} | grep java | awk '{print \$8}'\`
fi
if [ "\${ASTERISK_PID}" != "" ]; then
  ASTERISK_CPU=\`/usr/bin/pidstat -p \${ASTERISK_PID} | grep asterisk | awk '{print \$8}'\`
fi

echo "{"
echo "  \"tomcat\": \"\${TOMCAT_CPU}\","
echo "  \"goemon\": \"\${GOEMON_CPU}\","
echo "  \"asterisk\": \"\${ASTERISK_CPU}\""
echo "}"

exit 0
EOF

chmod 500 /root/sh/cpus.sh
chown root. /root/sh/cpus.sh
ln -s /root/sh/cpus.sh /usr/bin/cpus
