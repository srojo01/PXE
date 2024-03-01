#!/bin/bash
sudo zypper refresh
sudo zypper install atftp yast2-tftp-server
sudo atftp --version
sudo yast2 tftp-server
