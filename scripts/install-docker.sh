#!/bin/bash
sudo apt update
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
echo "Reinicie a sessão."
