#!/bin/bash


# check custom configurations
echo "CUSTOM CONFIGURATIONS"
echo "====================="
for key in "${!_UTILITY_FILE_MAP[@]}"; do
    echo "Key: $key , path: $(declare -p "$key")"
done

