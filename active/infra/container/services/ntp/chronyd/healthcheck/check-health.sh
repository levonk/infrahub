#!/bin/sh
set -e

# Check if chronyd is synchronized
chronyc tracking | grep -q 'Reference ID' && chronyc tracking | grep -v '00000000' 
