# Automated Project Bootstrapping & Process Management

## Project

This repository contains `deploy_agent.sh`, a shell automation script for deploying, running, and archiving a Student Attendance Tracker.

## Files

```text
deploy_agent.sh
templates/
├── attendance_checker.py
├── assets.csv
└── config.json
```

> **Important:** `attendance_checker.py` must be the unmodified file supplied by the course. It was not included in the uploaded files for this build, so copy the course version into `templates/attendance_checker.py` before running the deployment.

## Requirements

- Linux/macOS/WSL or the ALU WebTerm terminal
- `bash`
- `python3`
- `zip`

The deploy feature checks for `python3` and `zip` before creating the project.

## How to run

Make the master script executable:

```bash
chmod +x deploy_agent.sh
```

Then start the interactive menu:

```bash
./deploy_agent.sh
```

Menu:

1. **Deploy** — creates a new `attendance_tracker_<suffix>` project.
2. **Run** — runs an existing deployed project.
3. **Archive** — archives the generated logs.

Command-line forms are also supported:

```bash
./deploy_agent.sh deploy
./deploy_agent.sh run
./deploy_agent.sh archive
```

## Feature 1 — Deploy

The script asks for a suffix such as `class1`. It creates:

```text
attendance_tracker_class1/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
├── reports/
└── archives/
    ├── attendance/
    └── absent/
```

If the project already exists, the script asks before deleting/replacing it.

### Roster Option A

Copies the selected number of student rows from `templates/assets.csv`, keeping the header.

The supplied template has 10 students with four prior sessions each, so the deployed config remains:

```json
"total_sessions": 5
```

### Roster Option B

Generates a fresh roster from sample names/emails defined inside the shell script. Attendance and absence counts start at `0`.

Because a fresh roster has zero prior sessions, the script changes the deployed `total_sessions` to:

```json
"total_sessions": 1
```

The course specification also says the source `config.json` is deployed unmodified. The fresh-roster requirement necessarily needs `total_sessions=1`, so Option B is the one controlled exception: the script keeps the template's formatting/order and changes only that numeric value.

### Permissions

The script sets:

```text
attendance_checker.py -> executable
Helpers/config.json   -> 600
```

`600` means only the owner can read and write the config file.

### Threshold updates

The user can choose to update:

- warning threshold (default 75)
- failure threshold (default 50)

The script uses `sed -i` and targets the `"warning": <number>` and `"failure": <number>` lines specifically, without reordering or reformatting the JSON.

After setup, the deploy feature automatically starts `attendance_checker.py` as its verification step.

## Feature 2 — Run

Run an already deployed project:

```bash
./deploy_agent.sh run
```

Enter the project suffix. The script changes into the project directory and executes:

```bash
python3 attendance_checker.py
```

The application is interactive, so the instructor can mark a short live attendance session.

## Feature 3 — Archive logs

After a run:

```bash
./deploy_agent.sh archive
```

The script checks:

```text
reports/attendance.log
reports/absent.log
```

Each existing log is copied into its own archive directory with a timestamp:

```text
archives/
├── attendance/
│   └── attendance_YYYYMMDD_HHMMSS.log
└── absent/
    └── absent_YYYYMMDD_HHMMSS.log
```

If a log does not exist, the script reports that fact and continues without crashing.

## Ctrl+C / Ctrl+Z handling during deployment

During Feature 1, both signals are trapped:

- `Ctrl+C` → `SIGINT`
- `Ctrl+Z` → `SIGTSTP`

If either signal interrupts deployment, the script:

1. Prints a clear interruption message.
2. Archives whatever project directory exists so far.
3. Creates:

```text
attendance_tracker_<suffix>_archive.zip
```

4. Exits cleanly.

The archive contains the incomplete project directory and whatever files/directories had already been created.

The signal trap is removed before the interactive Python application starts, so it is specifically for the shell deployment process and not for an attendance-marking session.

## Testing checklist

### Test deployment

```bash
./deploy_agent.sh deploy
```

Choose a suffix and roster option. Verify:

```bash
ls -la attendance_tracker_<suffix>
ls -la attendance_tracker_<suffix>/Helpers
ls -la attendance_tracker_<suffix>/reports
```

Check permissions:

```bash
ls -l attendance_tracker_<suffix>/attendance_checker.py
ls -l attendance_tracker_<suffix>/Helpers/config.json
```

Expected config permission:

```text
-rw------- ... config.json
```

### Test run

```bash
./deploy_agent.sh run
```

Mark several students and verify:

```bash
ls -l attendance_tracker_<suffix>/reports
```

### Test archive

```bash
./deploy_agent.sh archive
```

Then:

```bash
ls -l attendance_tracker_<suffix>/archives/attendance
ls -l attendance_tracker_<suffix>/archives/absent
```

### Test Ctrl+C / Ctrl+Z

Start a deployment and interrupt it while the project is being created:

```bash
./deploy_agent.sh deploy
```

Press `Ctrl+C` or `Ctrl+Z` during deployment.

Verify the generated archive:

```bash
ls -l attendance_tracker_<suffix>_archive.zip
unzip -l attendance_tracker_<suffix>_archive.zip
```

## GitHub submission

Create a repository named:

```text
deploy_agent_GithubUsername
```

Then add:

```bash
git add deploy_agent.sh README.md templates/
git commit -m "Build automated attendance deployment agent"
git push
```

Include the run-through video link in the GitHub README before submitting.
