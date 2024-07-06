Bash
#!/bin/bash

# Check if a text file argument is provided
if [ $# -eq 0 ]; then
  echo "Error: Please provide a text file containing user data as an argument." >&2
  exit 1
fi

# Function to log actions with timestamps
log_action() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> /var/log/user_management.log
}

# Process user data from the provided file
while IFS=';' read -r username groups; do

  # Remove leading/trailing spaces
  username=${username## }
  username=${username%% }
  groups=${groups## }
  groups=${groups%% }

  # Check if user already exists
  if id -u "$username" >/dev/null 2>&1; then
    log_action "User '$username' already exists. Skipping..."
    continue
  fi

  # Create user and primary group (same as username)
  log_action "Creating user '$username' with primary group '$username'"
  useradd -M -g "$username" "$username" &>/dev/null

  # Check for errors during user creation
  if [ $? -ne 0 ]; then
    log_action "Error creating user '$username'"
    exit 1
  fi

  # Loop through each group (comma-separated) for the user
  for group in $(echo "$groups" | tr ',' ' '); do

    # Check if group exists
    if ! getent group "$group" >/dev/null 2>&1; then
      log_action "Creating group '$group'"
      groupadd "$group" &>/dev/null
    fi

    # Add user to the group
    log_action "Adding user '$username' to group '$group'"
    usermod -aG "$group" "$username" &>/dev/null
  done

  # Create home directory with appropriate permissions
  log_action "Creating home directory for user '$username'"
  mkdir -p "/home/$username"
  chown "$username:$username" "/home/$username"
  chmod 750 "/home/$username"

  # Generate random password
  password=$(openssl rand -base64 12)

  # Set user password and store securely
  log_action "Setting password for user '$username'"
  echo "$password" | passwd --stdin "$username" &>/dev/null

  # Store username and password (comma-separated) with restricted access
  echo "$username,$password" >> /var/secure/user_passwords.txt
  chmod 600 /var/secure/user_passwords.txt

done < "$1"

log_action "User creation script completed."