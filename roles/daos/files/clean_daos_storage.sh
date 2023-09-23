#!/bin/bash

echo "Stopping daos_server"
systemctl stop daos_server

echo "Unmounting /var/daos/ram"
umount /var/daos/ram

echo "Cleaning up /var/daos"
rm -rf /var/daos
mkdir -m 755 -p /var/daos

echo "Starting daos_server"
systemctl -q start daos_server

SECONDS=0
TIMEOUT=300

while true; do
    # Check the status of the service
    status=$(systemctl is-active daos_server)

    # If the service is active, break out of the loop
    if [[ $status == "active" ]]; then
        echo "The daos_server service is now running."
        break
    fi

    # If the TIMEOUT is reached, print an error message and exit the script
    if [[ $SECONDS -ge $TIMEOUT ]]; then
        echo "Error: The service failed to start within $(( TIMEOUT / 60 )) minutes."
        exit 1
    fi

    # Sleep for a short duration before checking again
    sleep 2
done

echo "Ready to format?"
dmg system query --rank-hosts="$HOSTNAME"

# dmg storage format -l "${HOSTNAME}"
# dmg system query -v -j --rank-hosts="${HOSTNAME}" | jq -r '.response.members[] | select(.fault_domain == "/${HOSTNAME}").state'
#
echo "To format run:"
echo "dmg storage format -l \"\${HOSTNAME}\""
echo
echo "To check status after formatting run:"
echo "dmg system query -v -j --rank-hosts=\"\${HOSTNAME}\" | jq -r --arg hostname \"/\${HOSTNAME}\" '.response.members[] | select(.fault_domain == \$hostname).state'"
echo
