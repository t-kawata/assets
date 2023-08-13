mkdir /usr/local/hanzo -m 755
mkdir /usr/local/hanzo/log -m 755
mkdir /usr/local/hanzo/bin -m 644
chown -R asterisk. /usr/local/hanzo

cat <<EOF > /usr/local/hanzo/bin/hanzo
#!/bin/bash
if [ "\$1" != "" ];then
  case "\$1" in
    start)
      if [ "\$2" != "" ];then
        /usr/local/hanzo/bin/start.php "\$2"
      else
        /usr/local/hanzo/bin/start.php
      fi
      ;;
    restart)
      if [ "\$2" != "" ];then
        /usr/local/hanzo/bin/restart.php "\$2"
      else
        /usr/local/hanzo/bin/restart.php
      fi
      ;;
    stop)
      /usr/local/hanzo/bin/stop.php
      ;;
    install)
      /usr/local/hanzo/bin/install.php
      ;;
    is_alive)
      /usr/local/hanzo/bin/is_alive.php
    esac
else
  echo "No args Error!!"
fi
exit 0
EOF
cat <<EOF > /usr/local/hanzo/bin/install.php
#!/usr/local/php/bin/php
<?php
define("JAR_NAME", "bl.jar");
define("LIB_DIR_NAME", "bl_lib");
define("HANZO_DIR", "/usr/local/hanzo/");
define("HOME_DIR", "/home/asterisk/");
define("FROM_JAR_PATH", HOME_DIR.JAR_NAME);
define("FROM_LIB_PATH", HOME_DIR.LIB_DIR_NAME);
define("TO_JAR_PATH", HANZO_DIR.JAR_NAME);
define("TO_LIB_PATH", HANZO_DIR.LIB_DIR_NAME);
define("RESOURCE_DIR_PATH", HANZO_DIR."resources/");
define("LINE", "----------------------------------------------------------------\n");

if (file_exists(FROM_JAR_PATH)) {
  echo LINE;
  echo "Found!! : ".FROM_JAR_PATH."\n";
  if (file_exists(TO_JAR_PATH)) {
    \$bak_path = TO_JAR_PATH."_bak";
    if (file_exists(\$bak_path)) { exec("rm -rf ".\$bak_path); }
    exec(sprintf("mv %s %s", TO_JAR_PATH, \$bak_path));
  }
  exec(sprintf("mv %s %s", FROM_JAR_PATH, TO_JAR_PATH));
  exec(sprintf("chmod 755 %s", TO_JAR_PATH));
  exec(sprintf("chown asterisk. %s", TO_JAR_PATH));
  if(file_exists(RESOURCE_DIR_PATH)){ exec(sprintf("rm -rf %s", RESOURCE_DIR_PATH)); }
  exec(sprintf("/usr/bin/jar vxf %s", TO_JAR_PATH));
  exec(sprintf("mkdir -p %s", RESOURCE_DIR_PATH));
  exec(sprintf("mv ./sounds %s", RESOURCE_DIR_PATH));
  exec("rm -rf ./hanzo");
  exec("rm -rf ./META-INF");
  exec("rm -rf ./master_mapper_xml");
  exec("rm -rf ./*.xml");
  echo "Hanzo-jar was successfully installed into ".TO_JAR_PATH."\n";
  echo LINE;
} else {
  echo LINE;
  echo "Not found : ".FROM_JAR_PATH."\n";
  echo LINE;
}

if (file_exists(FROM_LIB_PATH)) {
  echo LINE;
  echo "Found!! : ".FROM_LIB_PATH."\n";
  if (file_exists(TO_LIB_PATH)) {
    \$bak_path = TO_LIB_PATH."_bak";
    if (file_exists(\$bak_path)) { exec("rm -rf ".\$bak_path); }
    exec(sprintf("mv %s %s", TO_LIB_PATH, \$bak_path));
  }
  exec(sprintf("mv %s %s", FROM_LIB_PATH, TO_LIB_PATH));
  exec(sprintf("chmod -R 755 %s", TO_LIB_PATH));
  exec(sprintf("chown -R asterisk. %s", TO_LIB_PATH));
  echo "Hanzo-lib was successfully installed into ".TO_LIB_PATH."\n";
  echo LINE;
} else {
  echo LINE;
  echo "Not found : ".FROM_LIB_PATH."\n";
  echo LINE;
}

exit;
EOF
cat <<EOF > /usr/local/hanzo/bin/is_alive.php
#!/usr/local/php/bin/php
<?php
date_default_timezone_set("Asia/Tokyo");
\$Cont4573 = intval(exec("netstat -anp | grep LISTEN | grep :::4573 | wc -l"));
define("IS_RUNNING", (\$Cont4573 > 0 ? true : false));
if (IS_RUNNING) {
    echo "TRUE\n";
} else {
    echo "FALSE\n";
}
exit;
EOF
cat <<EOF > /usr/local/hanzo/bin/restart.php
#!/usr/local/php/bin/php
<?php
date_default_timezone_set("Asia/Tokyo");
\$log = false;
if (!empty(\$argv[1])) {
    if (\$argv[1] === "log") {
        \$log = true;
    }
}
define("LINE", "-------------------------------------------\n");
define("LOG", \$log);

\$rtn = array();

line();
message("Restarting HANZO...");

exec("/usr/local/hanzo/bin/stop.php", \$rtn);
sleep(2);
if (LOG) {
    exec("/usr/local/hanzo/bin/start.php log", \$rtn);
} else {
    exec("/usr/local/hanzo/bin/start.php", \$rtn);
}

foreach (\$rtn as \$item) { message(\$item); };

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
cat <<EOF > /usr/local/hanzo/bin/start.php
#!/usr/local/php/bin/php
<?php
date_default_timezone_set("Asia/Tokyo");
\$log = false;
if (!empty(\$argv[1])) {
    if (\$argv[1] === "log") {
        \$log = true;
    }
}
\$Cont4573 = intval(exec("netstat -anp | grep LISTEN | grep :::4573 | wc -l"));

define("HANZO_HOME", "/usr/local/hanzo");
define("HANZO_JAVA", "/usr/bin/java -Xms4096M -Xmx8192M -Dcom.sun.management.jmxremote -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.port=9010 -Dcom.sun.management.jmxremote.rmi.port=9010 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false");
define("HANZO_BIN", HANZO_HOME."/bl.jar");
define("HANZO_LOG_DIR", HANZO_HOME."/log/");
define("HANZO_LOG", HANZO_LOG_DIR."system.log");
define("HANZO_PID", HANZO_HOME."/pid/hanzo.pid");
define("LINE", "-------------------------------------------\n");
define("IS_RUNNING", (\$Cont4573 > 0 ? true : false));
define("LOG", \$log);

line();
if (!IS_RUNNING) {
    \$execArr = array();
    message("Starting HANZO...");
    if (LOG) {
        exec(sprintf("/usr/bin/log rotate %s 14", HANZO_LOG));
        exec(sprintf("nohup sudo -u asterisk %s -jar %s > %s 2>&1 &", HANZO_JAVA, HANZO_BIN, HANZO_LOG));
        exec(sprintf("chown asterisk. %s*.log", HANZO_LOG_DIR));
    } else {
        exec(sprintf("nohup sudo -u asterisk %s -jar %s > /dev/null 2>&1 &", HANZO_JAVA, HANZO_BIN));
    }
    line();
    message("HANZO ready!!");
} else {
    message("HANZO is already running");
}
line();

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
cat <<EOF > /usr/local/hanzo/bin/stop.php
#!/usr/local/php/bin/php
<?php
date_default_timezone_set("Asia/Tokyo");
\$Cont4573 = intval(exec("netstat -anp | grep LISTEN | grep :::4573 | wc -l"));

define("LINE", "-------------------------------------------\n");
define("IS_RUNNING", (\$Cont4573 > 0 ? true : false));

line();
if (IS_RUNNING) {
    define("PID", exec("netstat -anp | grep LISTEN | grep 4573 | awk '{print \$7}' | awk -F/ '{print \$1}'"));
    message("Stopping HANZO...");
    line();
    exec(sprintf("kill %s", PID));
    message("HANZO stopped!!");
} else {
    message("HANZO is already stopped");
}
line();

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
cat <<EOF > /root/sh/restart_hanzo.sh
#!/bin/bash
LINE="------------------------------------------------"
SLACK_URL="https://hooks.slack.com/services/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"
CHK_LIMIT=5
ZERO=0
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
  echo ">> Forcibly restart Hanzo with option '-hard'. <<"
  TEXT=\$TEXT"\\n""[ Forcibly restart Hanzo with option '-hard'. ]"
fi
if [ \${ACTIVE_CHANNELS_CNT} = 0 -o "\${ARG}" = "\${HARD}" ]; then
  HOSTNAME=\`hostname\`
  TEXT=\$TEXT"\\n \\\`Hanzo is dead now (\${HOSTNAME}).\\\` "
  TEXT=\$TEXT"\\n""\${HOSTNAME}"
  echo "Restarting Hanzo..."
  /usr/bin/hanzo install
  systemctl restart hanzo
  sleep 2
  CHK_NUM=\`netstat -anp | grep LISTEN | grep 4573 | grep java | wc -l\`
  CHK_CNT=0
  SUCCESS=false
  if [ \${CHK_NUM} -gt \${ZERO} ]; then
    CHK_GO=false
    SUCCESS=true
  else
    CHK_GO=true
  fi
  while [ \${CHK_GO} ]
  do
    CHK_CNT=\$CHK_CNT+1
    sleep 1
    CHK_NUM=\`netstat -anp | grep LISTEN | grep 4573 | grep java | wc -l\`
    if [ \${CHK_NUM} -gt \${ZERO} ]; then
      CHK_GO=false
      SUCCESS=true
      break
    fi
    echo \${CHK_CNT}
    if [ \${CHK_CNT} -ge \${CHK_LIMIT} ]; then
      CHK_GO=false
      break
    fi
  done

  if [ \${SUCCESS} ]; then
    MSG="Succeeded to restart hanzo !!"
  else
    MSG="Failed to restart hanzo..."
  fi

  echo \${MSG}
  echo \${LINE}
  TEXT=\$TEXT"\\n"\${MSG}
  TEXT=\$TEXT"\\n"\${LINE}
  /usr/bin/curl -X POST "\${SLACK_URL}" -d "payload={\\"username\\": \\"pbx-alert@\${HOSTNAME}\\",\\"text\\": \\"\${TEXT}\\",\\"icon_emoji\\": \\":exclamation:\\"}"
else
  echo "Sorry! Try again when Asterisk has no active channels!"
  echo \${LINE}
  TEXT=\$TEXT"\\n"\${LINE}
fi
exit 0
EOF
chmod 500 /root/sh/restart_hanzo.sh
ln -s /root/sh/restart_hanzo.sh /usr/bin/restart_hanzo

chown asterisk. /usr/local/hanzo/bin/*
chmod 755 /usr/local/hanzo/bin/*

ln -s /usr/local/hanzo/bin/hanzo /usr/bin/hanzo

cat <<EOF > /lib/systemd/system/hanzo.service
[Unit]
Description=HANZO

[Service]
LimitNOFILE=10240
ExecStart=/usr/bin/hanzo start log
Restart=always
Type = simple
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

chmod 755 /lib/systemd/system/hanzo.service
