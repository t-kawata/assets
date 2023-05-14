#!/bin/bash

expect -c "
  set timeout 2
  spawn vncpasswd

  expect \"Password:\"
  send \"kawata\n\"

  expect \"Verify:\"
  send \"kawata\n\"

  expect \"Would you like to enter a view-only password (y/n)? \"
  send \"n\n\"

  expect \"A view-only password is not used\"

  exit 0
"

tigervncserver :1

websockify -D --web=/usr/share/novnc/ 6080 localhost:5901

exit 0
