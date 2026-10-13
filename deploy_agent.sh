#!/bin/bash

# Student Attendance Tracker Deployment Agent

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
PROJECT_DIR=""

# Check if a command is installed
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: $1 is not installed."
        exit 1
    }
}

# Handle Ctrl+C and Ctrl+Z during deployment
deployment_interrupted() {
    echo
    echo "Deployment interrupted by Ctrl+C or Ctrl+Z."

    if [[ -d "$PROJECT_DIR" ]]; then
        ARCHIVE="${PROJECT_DIR}_archive.zip"

        echo "Creating archive of incomplete project..."

        rm -f "$ARCHIVE"
        cd "$SCRIPT_DIR" || exit 1
        zip -rq "$ARCHIVE" "$(basename "$PROJECT_DIR")"

        if [[ -f "$ARCHIVE" ]]; then
            echo "Archive created: $ARCHIVE"
            rm -rf "$PROJECT_DIR"
            echo "Incomplete project directory removed."
        else
            echo "WARNING: Archive could not be created."
        fi
    fi

    exit 130
}

# Deploy a new project
deploy() {
    check_command python3
    check_command zip

    [[ -f "$TEMPLATES/attendance_checker.py" ]] || {
        echo "ERROR: attendance_checker.py is missing."
        exit 1
    }

    [[ -f "$TEMPLATES/config.json" ]] || {
        echo "ERROR: config.json is missing."
        exit 1
    }

    [[ -f "$TEMPLATES/assets.csv" ]] || {
        echo "ERROR: assets.csv is missing."
        exit 1
    }

    read -r -p "Enter project suffix: " name

    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "ERROR: Invalid project name."
        exit 1
    fi

    PROJECT_DIR="$SCRIPT_DIR/attendance_tracker_$name"

    # Enable signal handling only during deployment
    trap deployment_interrupted SIGINT SIGTSTP

    # Handle an existing project
    if [[ -d "$PROJECT_DIR" ]]; then
        read -r -p "Project already exists. Overwrite? (y/N): " answer

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            echo "Deployment cancelled."
            trap - SIGINT SIGTSTP
            return
        fi
    fi

    echo "Creating project..."

    mkdir -p "$PROJECT_DIR/Helpers"
    mkdir -p "$PROJECT_DIR/reports"
    mkdir -p "$PROJECT_DIR/archives/attendance"
    mkdir -p "$PROJECT_DIR/archives/absent"

    cp "$TEMPLATES/attendance_checker.py" \
       "$PROJECT_DIR/attendance_checker.py"

    cp "$TEMPLATES/config.json" \
       "$PROJECT_DIR/Helpers/config.json"

    # Create roster
    echo
    echo "Choose roster option:"
    echo "1) Use template roster"
    echo "2) Create fresh roster"

    read -r -p "Choose 1 or 2: " option

    if [[ "$option" == "1" ]]; then

        read -r -p "How many students to copy? (1-10): " count

        if [[ ! "$count" =~ ^[0-9]+$ ]] || \
           (( count < 1 || count > 10 )); then
            echo "ERROR: Invalid number of students."
            exit 1
        fi

        # Copy the header row plus the requested number of student rows
        head -n 1 "$TEMPLATES/assets.csv" \
            > "$PROJECT_DIR/Helpers/assets.csv"

        tail -n +2 "$TEMPLATES/assets.csv" \
            | head -n "$count" \
            >> "$PROJECT_DIR/Helpers/assets.csv"

        echo "Template roster copied ($count students)."

    elif [[ "$option" == "2" ]]; then

        names=("Milka" "Axel" "Ryan" "Davis" "Kevin" "Kentha" "Calvin" "Caidy" "Vaillant" "Diane")
        emails=(
            "milka@alustudent.com"
            "axel@alustudent.com"
            "ryan@alustudent.com"
            "davis@alustudent.com"
            "kevin@alustudent.com"
            "kentha@alustudent.com"
            "calvin@alustudent.com"
            "caidy@alustudent.com"
            "vaillant@alustudent.com"
            "diane@alustudent.com"
        )

        read -r -p "How many students? (1-${#names[@]}): " count

        if [[ ! "$count" =~ ^[0-9]+$ ]] || \
           (( count < 1 || count > ${#names[@]} )); then
            echo "ERROR: Invalid number of students."
            exit 1
        fi

        echo "Email,Names,Attendance Count,Absence Count" \
            > "$PROJECT_DIR/Helpers/assets.csv"

        for ((i=0; i<count; i++)); do
            echo "${emails[$i]},${names[$i]},0,0" \
                >> "$PROJECT_DIR/Helpers/assets.csv"
        done

        # Fresh roster starts with one session
        sed -i -E \
            's/^([[:space:]]*"total_sessions"[[:space:]]*:[[:space:]]*)[0-9]+/\11/' \
            "$PROJECT_DIR/Helpers/config.json"

        echo "Fresh roster created."

    else
        echo "ERROR: Invalid option."
        exit 1
    fi

    # Set permissions
    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"

    echo
    echo "Permissions configured."

    # Update thresholds
    read -r -p "Update warning/failure thresholds? (y/N): " update

    if [[ "$update" =~ ^[Yy]$ ]]; then

        read -r -p "Warning threshold: " warning
        read -r -p "Failure threshold: " failure

        if [[ ! "$warning" =~ ^[0-9]+$ ]] || \
           [[ ! "$failure" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Thresholds must be numbers."
            exit 1
        fi

        sed -i -E \
            "s/^([[:space:]]*\"warning\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$warning/" \
            "$PROJECT_DIR/Helpers/config.json"

        sed -i -E \
            "s/^([[:space:]]*\"failure\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$failure/" \
            "$PROJECT_DIR/Helpers/config.json"

        echo "Thresholds updated."
    fi

    # Deployment finished, so stop signal trap
    trap - SIGINT SIGTSTP

    echo
    echo "Deployment completed successfully."
    echo "Running attendance checker..."

    cd "$PROJECT_DIR" || exit 1
    python3 attendance_checker.py
}

# Run an existing project
run_app() {
    check_command python3

    read -r -p "Enter project suffix: " name

    PROJECT_DIR="$SCRIPT_DIR/attendance_tracker_$name"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo "ERROR: Project does not exist."
        exit 1
    fi

    cd "$PROJECT_DIR" || exit 1
    python3 attendance_checker.py
}

# Archive attendance and absence logs
archive_logs() {
    read -r -p "Enter project suffix: " name

    PROJECT_DIR="$SCRIPT_DIR/attendance_tracker_$name"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo "ERROR: Project does not exist."
        exit 1
    fi

    timestamp=$(date '+%Y%m%d_%H%M%S')

    mkdir -p "$PROJECT_DIR/archives/attendance"
    mkdir -p "$PROJECT_DIR/archives/absent"

    if [[ -f "$PROJECT_DIR/reports/attendance.log" ]]; then
        dest="$PROJECT_DIR/archives/attendance/attendance_${timestamp}.log"
        cp "$PROJECT_DIR/reports/attendance.log" "$dest"

        echo "Attendance log archived -> $dest"
    else
        echo "No attendance.log found."
    fi

    if [[ -f "$PROJECT_DIR/reports/absent.log" ]]; then
        dest="$PROJECT_DIR/archives/absent/absent_${timestamp}.log"
        cp "$PROJECT_DIR/reports/absent.log" "$dest"

        echo "Absence log archived -> $dest"
    else
        echo "No absent.log found."
    fi
}

# Main menu
echo "Automated Project Bootstrapping & Process Management"
echo "1) Deploy"
echo "2) Run"
echo "3) Archive logs"

read -r -p "Choose an option (1-3): " choice

case "$choice" in
    1) deploy ;;
    2) run_app ;;
    3) archive_logs ;;
    *) echo "Invalid choice." ;;
esac