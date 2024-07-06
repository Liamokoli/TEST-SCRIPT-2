Bash
#!/bin/bash

# Script configuration
USER_FILE="$1"  # Path to the file containing usernames and groups
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to generate a random password
function generate_random_password() {
  local length=12  # Default password length
  if [[ -n "$1" ]]; then length="$1"; fi
  cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w "$length" | head -n 1
}

# Function to create a user and log actions
function create_user() {
  local username="$1"
  local groups="$2"

  # Check if user already exists
  if id -u "$username" >/dev/null 2>&1; then
    echo "User '$username' already exists. Skipping..." >> "$LOG_FILE"
    return 1
  fi

  # Create user group (same as username)
  groupadd "$username" &>> "$LOG_FILE"
  if [[ $? -ne 0 ]]; then
    echo "Failed to create group '$username'" >> "$LOG_FILE"
    return 1
  fi

  # Create user with home directory
  useradd -m -g "$username" -s /bin/bash "$username" &>> "$LOG_FILE"
  if [[ $? -ne 0 ]]; then
    echo "Failed to create user '$username'" >> "$LOG_FILE"
    return 1
  fi

  # Set ownership and permissions for home directory
  chown -R "$username:$username" "/home/$username" &>> "$LOG_FILE"
  chmod 700 "/home/$username" &>> "$LOG_FILE"

  # Generate random password
  password=$(generate_random_password)

  # Set password and store it securely
  echo "$username:$password" >> "$PASSWORD_FILE"
  echo "$password" | passwd --stdin "$username" &>> "$LOG_FILE"
  if [[ $? -ne 0 ]]; then
    echo "Failed to set password for user '$username'" >> "$LOG_FILE"
    return 1
  fi

  # Add user to specified groups
  for group in $(echo "$groups" | tr ',' ' '); do
    usermod -a -G "$group" "$username" &>> "$LOG_FILE"
    if [[ $? -ne 0 ]]; then
      echo "Failed to add user '$username' to group '$group'" >> "$LOG_FILE"
    fi
  done

  echo "User '$username' created successfully." >> "$LOG_FILE"
}

# Check for input file
if [[ -z "$USER_FILE" ]]; then
  echo "Error: Please provide the user file path as an argument."
  exit 1
fi

# Check if user and password files exist and have proper permissions
if [[ ! -f "$LOG_FILE" || ! -w "$LOG_FILE" ]]; then
  echo "Error: Log file '$LOG_FILE' does not exist or is not writable."
  exit 1
fi

if [[ ! -f "$PASSWORD_FILE" || ! -w "$PASSWORD_FILE" ]]; then
  echo "Error: Password file '$PASSWORD_FILE' does not exist or is not writable."
  exit 1
fi

# Process user file
echo "Starting user creation..." >> "$LOG_FILE"
while IFS= read -r line; do
  username=$(cut -d ';' -f1 <<< "$line")
  groups=$(cut -d ';' -f2- <<< "$line")
  create_user "$username" "$groups"
done < "$USER_FILE"

echo "User creation completed." >> "$LOG_FILE"

exit 0