#!/bin/bash

sudo zypper refresh && sudo zypper update 
sudo zypper install openssh
sudo systemctl start sshd
sudo systemctl enable sshd
sudo systemctl status sshd
