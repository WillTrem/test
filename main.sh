#!/bin/bash
# set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
APP_PATH="$SCRIPT_DIR/apps"
LOG_FILE="$SCRIPT_DIR/current.log"

# Parse command line options
ACTION=""
PROFILE="dev"

print_help() {
  echo "Usage: $0 [--profile PROFILE] {up|down|pull|reboot|reset-app|reset-apps|drop-apps|logs|lint|export|import}"
  echo "  up                       : Start all services using the specified profile (default: dev)"
  echo "  down                     : Stop all services"
  echo "  pull                     : Pull the latest images"
  echo "  sync-template            : Synchronizes the repo with the template repository"
  echo "  logs                     : Follow the logs of the services (optionally specify services as csv)"
  echo "  load-apps [<app_names>]  : Load apps into the system (optionally specify apps as csv)"
  echo "  drop-apps [<app_names>]  : Drop apps from the system (optionally specify apps as csv)"
  echo "  reset-apps [<app_names>] : Reset apps and their data (optionally specify app names as csv)"
  echo "  reboot                   : Resets everything in the database except the users"
  echo "  lint                     : Lints all the sql files under apps/ "
  echo "  export                   : Exports the app configuration and translation data to files in configs/"
  echo "  import                   : Imports the app configuration from configs/latest/"
  echo "                              and translation data from configs/lang.json "
  echo "  init                     : Initializes permissions for bind mount volumes"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --profile)
    PROFILE="$2"
    shift
    ;;
  up | down | pull | reboot | import | export | init | lint | sync-template)
    ACTION="$1"
    shift
    break
    ;;
  load-apps | drop-apps | reset-apps)
    ACTION="$1"
    APP_NAMES="$2"
    shift 2
    break 
    ;;
  logs)
    ACTION="logs"
    shift
    SERVICES="${*:-}"
    break
    ;;
  *)
    echo "Unknown parameter passed: $1"
    print_help
    ;;
  esac
  shift
done

show_confirmation_prompt(){
  local message=$1
  read -p "$message [y/N] " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation aborted."
        exit 1
    fi
}

compose_pull() {
  docker compose --env-file "./env/.env" pull
}

compose_down() {
  docker compose --profile "$1" --env-file "./env/.env" down
}

compose_up() {
  compose_down "*" && compose_pull && docker volume rm 'pgadmin-config' 'pgadmin-data' 'front-end-config' 'front-end-apps' 2>/dev/null; docker compose --profile "$1" --env-file "./env/.env" up -d --force-recreate --build
}

compose_up_fast() {
  docker compose --profile "$1" --env-file "./env/.env" up -d
}


compose_logs() {
  local profile="$1"
  local services="${2:-}"
  if [ -n "$services" ]; then
    IFS=',' read -r -a service_array <<<"$services"
    docker compose --profile "$profile" --env-file "./env/.env" logs -f "${service_array[@]}"
  else
    docker compose --profile "$profile" --env-file "./env/.env" logs -f
  fi
}

load-apps(){
  local app_names="$1";

  if [[ -n app_name ]]; then
    IFS=',' read -r -a app_array <<<"$app_names"
    for app_name in "${app_array[@]}"; do
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/load_apps.sh --app "$app_name"
    done
  else
    docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/load_apps.sh
  fi  

}

drop-apps(){
    local app_names="$1";

  if [[ -n app_name ]]; then
    IFS=',' read -r -a app_array <<<"$app_names"
    for app_name in "${app_array[@]}"; do
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh --app "$app_name"
    done
  else
    docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh 
  fi  
}

reset-apps() {
  local app_names="$1";

  if [[ -n app_name ]]; then
    IFS=',' read -r -a app_array <<<"$app_names"
    for app_name in "${app_array[@]}"; do
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh --app "$app_name"
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/load_apps.sh --app "$app_name"
    done
  else
    docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh 
    docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/load_apps.sh
  fi  
}

reboot() {
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/hard_reboot.sh
}

import-all(){
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/import_all.sh
}
export-all(){
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/export_all.sh
}

init_user_permissions() {
  # Check if the user is not running the command on linux
  if [ "$(uname)" != "Linux"  ]; then
    echo "You're not using Linux, you're already good to go!"
    exit 1
  fi

  local group_id=1024
  local group_name="volumes"

  # Check if the group exists, if not, create it
  if ! getent group "$group_id" > /dev/null; then
    sudo groupadd -g "$group_id" "$group_name"
    echo "Group $group_name ($group_id) has been created"
  fi

  # Check if the current user is part of the group, if not, add the user
  if ! id -nG "$USER" | grep -qw "$group_name"; then
    sudo usermod -aG "$group_name" "$USER"
    echo "User $USER has been added to group $group_name ($group_id)"
  fi
    sudo chown -R $USER:1024 ./configs
    sudo chmod -R g+srw,o-rwx ./configs # Granting access to users in the 'volumes' group only
    sudo chown -R $USER:1024 ./apps
    sudo chmod -R g+srw,o-rwx ./apps # Granting access to users in the 'volumes' group only

    echo "Permission setup complete!"
    echo "Please close and re-open ALL VSCode pages for the changes to take effect."
    # restart vscode completely after this
}


lint(){
  docker exec -w //app/extension/shell-scripts adaptive-ui bash -c "source /app/venv/bin/activate && /app/extension/shell-scripts/lint_sql.sh ../../apps/"
}

sync-template(){
  local remote_name="template"
  local remote_url="https://github.com/AlbatrosServiceAgile/TemplateForApps.git"

  # Check if the command is ran in the template repo   
  if git remote get-url origin | grep -qw "$remote_url"; then
    echo "The sync-template command cannot be ran in the template repository."
    exit 1
  fi

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "There are uncommitted changes in the repository."
    echo "Please commit or stash them before running sync-template."
    exit 1
  fi

  # Check if a "template" remote has already been setup
  if ! git remote | grep -qw "$remote_name"; then
    git remote add -t main "$remote_name" "$remote_url"
    git remote set-url --push "$remote_name" DISALLOWED
  fi

  local gitignore_exists=$( [ -f .gitignore ] && echo true || echo false )
  git fetch "$remote_name"  && \
  git merge template/main --allow-unrelated-histories --squash --strategy-option theirs && \
  if [ "$gitignore_exists" = true ]; then git checkout HEAD -- .gitignore; else git rm -f .gitignore; fi  

  # Check if the merge brought any changes
  if git diff-index --quiet HEAD --; then
    echo "No new changes from the template remote."
    git merge --abort
    exit 1
  fi
  
  # Prevent merging .gitignore file
  git commit -m "Merge remote-tracking branch 'template/main' from template repository" && \
  git push && \
  echo "Sync with template remote successful"
}


case "$ACTION" in
init) init_user_permissions ;;
up) compose_up "$PROFILE" ;;
down) compose_down "*" ;;
pull) compose_pull ;;
reboot) reboot ;;
load-apps) load-apps $APP_NAMES ;;
reset-apps) reset-apps $APP_NAMES ;;
drop-apps) drop-apps $APP_NAMES ;;
logs) compose_logs "$PROFILE" "$SERVICES" ;;
lint) lint ;;
export) export-all ;;
import) import-all ;;
sync-template) sync-template ;;
*) print_help ;;
esac
