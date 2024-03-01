#!/bin/bash

sudo zypper refresh
sudo zypper repos
sudo zypper addrepo http://download.opensuse.org/distribution/leap/15.5/repo/oss/ opensuse-oss
sudo zypper refresh
sudo zypper install dhcp-server
