#!/bin/bash

REPO_URL="https://github.com/subashglobalyhub/monitoring-agent-setup.git"
TARGET_DIR="$HOME/monitoring-agent-setup"
TARGET_SCRIPT="agent-setup.sh"

echo "Starting the repository clone and running the test.sh script..."

# Check if the directory already exists
if [ -d "$TARGET_DIR" ]; then
    echo "Directory '$TARGET_DIR' already exists. Pulling latest changes..."
    cd $TARGET_DIR
    git pull origin main
    if [ $? -eq 0 ]; then
        echo "Repository updated successfully."
    else
        echo "Failed to pull the latest changes."
        exit 1
    fi
else
    echo "Directory '$TARGET_DIR' does not exist. Cloning the repository..."
    git clone $REPO_URL
    if [ $? -eq 0 ]; then
        echo "Repository cloned successfully."
        cd $TARGET_DIR
    else
        echo "Failed to clone the repository."
        exit 1
    fi
fi

# Check if the target script exists and run it
if [ -f "$TARGET_SCRIPT" ]; then
    echo "Running $TARGET_SCRIPT script..."
    cd $TARGET_DIR
    chmod +x $TARGET_SCRIPT
    ./$TARGET_SCRIPT -e production
    echo "$TARGET_SCRIPT executed successfully."
else
    echo "$TARGET_SCRIPT script not found in the repository."
fi

echo "Script execution completed."
