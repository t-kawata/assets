mkdir /usr/local/goemon -m 755
mkdir /usr/local/goemon/log -m 755
mkdir /usr/local/goemon/bin -m 644
chown -R asterisk. /usr/local/goemon

cat <<EOF > /usr/local/goemon/bin/goemon
#!/bin/bash
if [ "\$1" != "" ];then
  case "\$1" in
    start)
      if [ "\$2" != "" ];then
        /usr/local/goemon/bin/start.php "\$2"
      else
        /usr/local/goemon/bin/start.php
      fi
      ;;
    restart)
      if [ "\$2" != "" ];then
        /usr/local/goemon/bin/restart.php "\$2"
      else
        /usr/local/goemon/bin/restart.php
      fi
      ;;
    stop)
      /usr/local/goemon/bin/stop.php
      ;;
    install)
      /usr/local/goemon/bin/install.php
      ;;
    is_alive)
      /usr/local/goemon/bin/is_alive.php
    esac
else
  echo "No args Error!!"
fi
exit 0
EOF
cat <<EOF > /usr/local/goemon/bin/install.php
#!/usr/local/php/bin/php
<?php
define("JAR_NAME", "amaze_bl.jar");
define("LIB_DIR_NAME", "amaze_bl_lib");
define("GOEMON_DIR", "/usr/local/goemon/");
define("HOME_DIR", "/home/asterisk/");
define("FROM_JAR_PATH", HOME_DIR.JAR_NAME);
define("FROM_LIB_PATH", HOME_DIR.LIB_DIR_NAME);
define("TO_JAR_PATH", GOEMON_DIR.JAR_NAME);
define("TO_LIB_PATH", GOEMON_DIR.LIB_DIR_NAME);
define("RESOURCE_DIR_PATH", GOEMON_DIR."resources/");
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
  exec("rm -rf ./goemon");
  exec("rm -rf ./META-INF");
  exec("rm -rf ./master_mapper_xml");
  exec("rm -rf ./*.xml");
  echo "Goemon-jar was successfully installed into ".TO_JAR_PATH."\n";
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
  echo "Goemon-lib was successfully installed into ".TO_LIB_PATH."\n";
  echo LINE;
} else {
  echo LINE;
  echo "Not found : ".FROM_LIB_PATH."\n";
  echo LINE;
}

exit;
EOF
cat <<EOF > /usr/local/goemon/bin/is_alive.php
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
cat <<EOF > /usr/local/goemon/bin/restart.php
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
message("Restarting GOEMON...");

exec("/usr/local/goemon/bin/stop.php", \$rtn);
sleep(2);
if (LOG) {
    exec("/usr/local/goemon/bin/start.php log", \$rtn);
} else {
    exec("/usr/local/goemon/bin/start.php", \$rtn);
}

foreach (\$rtn as \$item) { message(\$item); };

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
cat <<EOF > /usr/local/goemon/bin/start.php
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

define("GOEMON_HOME", "/usr/local/goemon");
define("GOEMON_JAVA", "/usr/bin/java -Xms4096M -Xmx8192M -Dcom.sun.management.jmxremote -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.port=9010 -Dcom.sun.management.jmxremote.rmi.port=9010 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false");
define("GOEMON_BIN", GOEMON_HOME."/amaze_bl.jar");
define("GOEMON_LOG_DIR", GOEMON_HOME."/log/");
define("GOEMON_LOG", GOEMON_LOG_DIR."system.log");
define("GOEMON_PID", GOEMON_HOME."/pid/goemon.pid");
define("LINE", "-------------------------------------------\n");
define("IS_RUNNING", (\$Cont4573 > 0 ? true : false));
define("LOG", \$log);

line();
if (!IS_RUNNING) {
    \$execArr = array();
    message("Starting GOEMON...");
    if (LOG) {
        exec(sprintf("/usr/bin/log rotate %s 14", GOEMON_LOG));
        exec(sprintf("nohup sudo -u asterisk %s -jar %s > %s 2>&1 &", GOEMON_JAVA, GOEMON_BIN, GOEMON_LOG));
        exec(sprintf("chown asterisk. %s*.log", GOEMON_LOG_DIR));
    } else {
        exec(sprintf("nohup sudo -u asterisk %s -jar %s > /dev/null 2>&1 &", GOEMON_JAVA, GOEMON_BIN));
    }
    line();
    message("GOEMON ready!!");
} else {
    message("GOEMON is already running");
}
line();

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
cat <<EOF > /usr/local/goemon/bin/stop.php
#!/usr/local/php/bin/php
<?php
date_default_timezone_set("Asia/Tokyo");
\$Cont4573 = intval(exec("netstat -anp | grep LISTEN | grep :::4573 | wc -l"));

define("LINE", "-------------------------------------------\n");
define("IS_RUNNING", (\$Cont4573 > 0 ? true : false));

line();
if (IS_RUNNING) {
    define("PID", exec("netstat -anp | grep LISTEN | grep 4573 | awk '{print \$7}' | awk -F/ '{print \$1}'"));
    message("Stopping GOEMON...");
    line();
    exec(sprintf("kill %s", PID));
    message("GOEMON stopped!!");
} else {
    message("GOEMON is already stopped");
}
line();

function line() { echo LINE; }
function message(\$msg) { echo \$msg."\n"; }
EOF
where
chmod 500 /root/sh/restart_goemon.sh
ln -s /root/sh/restart_goemon.sh /usr/bin/restart_goemon

chown asterisk. /usr/local/goemon/bin/*
chmod 755 /usr/local/goemon/bin/*

ln -s /usr/local/goemon/bin/goemon /usr/bin/goemon

cat <<EOF > /lib/systemd/system/goemon.service
[Unit]
Description=GOEMON

[Service]
LimitNOFILE=10240
ExecStart=/usr/bin/goemon start log
Restart=always
Type = simple
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

chmod 755 /lib/systemd/system/goemon.service

