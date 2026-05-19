#!/bin/bash
docker compose down -v
docker compose up --build -d
echo "[+] Lab reset complete."
