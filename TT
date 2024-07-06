#!/bin/bash

# Check if the script is run with a file argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <user-file>"
    exit 1
fi

USER_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASS_FILE="/var/secure/user_passwords.csv"

# Create log and password files if they don't exist
touch $LOG_FILE
mkdir -p /var/secure
touch $PASS_FILE
chmod 600 $PASS_FILE

log_action() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Read the user file line by line
while IFS=';' read -r username groups; do
    # Remove leading and trailing whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Create user if it does not exist
    if id "$username" &>/dev/null; then
        log_action "User $username already exists."
    else
        # Create personal group for the user
        groupadd "$username" &>/dev/null
        # Create user with home directory and personal group
        useradd -m -g "$username" -s /bin/bash "$username"
        if [ $? -eq 0 ]; then
            log_action "User $username created."
        else
            log_action "Failed to create user $username."
            continue
        fi

        # Set home directory permissions
        chmod 700 "/home/$username"
        chown "$username:$username" "/home/$username"

        # Generate and set password
        password=$(generate_password)
        echo "$username:$password" | chpasswd
        log_action "Password set for $username."
        echo "$username,$password" >> $PASS_FILE
    fi

    # Add user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo $group | xargs)
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            log_action "Group $group created."
        fi
        usermod -aG "$group" "$username"
        log_action "User $username added to group $group."
    done

done < "$USER_FILE"

log_action "User creation script completed."


