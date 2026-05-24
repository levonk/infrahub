watch -n 300 date ; echo '---' ; docker exec $1 du -sm /nix ; echo '---' ; docker exec $1 find /nix/store -maxdepth 1 -type d | wc -l
