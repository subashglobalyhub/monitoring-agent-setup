#!/bin/bash

# Define repository URL and target directory
REPO_URL="https://github.com/subashglobalyhub/monitoring-agent-setup.git"
TARGET_DIR="monitoring-agent-setup"
TARGET_SCRIPT="agent-setup.sh"


echo "Starting the repository clone and running the test.sh script..."
git clone $REPO_URL
if [ $? -eq 0 ]; then
    echo "Repository cloned successfully."
    cd $TARGET_DIR
    if [ -f "$TARGET_SCRIPT" ]; then
        echo "Running test.sh script..."
        chmod +x $TARGET_SCRIPT
        ./$TARGET_SCRIPT -e production
        echo "$TARGET_SCRIPT executed successfully."
    else
        echo "$TARGET_SCRIPT script not found in the repository."
    fi
else
    echo "Failed to clone the repository."
fi
echo "Script execution completed."