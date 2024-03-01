#!/bin/bash
sudo zypper refresh
sudo zypper install atftp yast2-tftp-server
atftp --version
yast2 tftp-server
