#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
APP_PATH="$SCRIPT_DIR/apps"
LOG_FILE="$SCRIPT_DIR/current.log"

# Parse command line options
ACTION=""
PROFILE="dev"

print_help() {
  echo "Usage: $0 [--profile PROFILE] {up|down|pull|reboot|reset-app|reset-apps|drop-apps|logs|lint|export|import}"
  echo "  up                   : Start all services using the specified profile (default: dev)"
  echo "  down                 : Stop all services"
  echo "  pull                 : Pull the latest images"
  echo "  logs                 : Follow the logs of the services (optionally specify services as csv)"
  echo "  reboot                : Resets everything in the database except the users"
  echo "  reset-app <app_name> : Reset only an application and its data"
  echo "  reset-apps           : Reset all the applications and their data"
  echo "  drop-apps <app_name> : Drops an application (all applications if none is provided)"
  echo "  lint                 : Lints all the sql files under apps/ "
  echo "  export               : Exports the app configuration and translation data to files in configs/"
  echo "  import               : Imports the app configuration and translation data from files in configs/"
  echo "  init                 : Initializes permissions for bind mount volumes"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --profile)
    PROFILE="$2"
    shift
    ;;
  up | down | pull | reboot | reset-apps | import | export | init | lint)
    ACTION="$1"
    shift
    break
    ;;
  reset-app)
    if [ $# -ne 2 ]; then
      echo "Error: reset-app requires exactly one argument (app_name)"
    fi
    ACTION="reset-app"
    APP_NAME="$2"
    shift 2
    break
    ;;
  drop-apps)
    ACTION="$1"
    APP_NAME="$2"
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

# reset_volumes() {
#   docker volume rm db-data-test || true
#   docker volume rm minio_data || true
# }

reboot() {
  # compose_down "$PROFILE" &&
  #   reset_volumes &&
  #   compose_pull &&
  #   compose_up "$PROFILE"
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/hard_reboot.sh
}


reset-app() {
  local app_name="$1"
  compose_up_fast "$PROFILE"
  # "$SCRIPT_DIR/drop_apps.sh" --profile "$PROFILE" --app "$app_name"
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh --app "$app_name"
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/load_apps.sh --app "$app_name"
}

reset-apps() {
  compose_up_fast "$PROFILE"
  # "$SCRIPT_DIR/drop_apps.sh" --profile "$PROFILE"
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh 
  docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/refresh_apps.sh

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

drop_apps(){
    local app_name=$1
    show_confirmation_prompt "Are you sure that you want to drop ${app_name:-all apps}?"

    if [[ -n app_name ]]; then 
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh --app "$app_name"
    else
      docker exec -w //app/extension/shell-scripts adaptive-ui //app/extension/shell-scripts/drop_apps.sh 
    fi
}

lint(){
  docker exec -w //app/extension/shell-scripts adaptive-ui bash -c "source /app/venv/bin/activate && /app/extension/shell-scripts/lint_sql.sh ../../apps/"
}


case "$ACTION" in
init) init_user_permissions ;;
up) compose_up "$PROFILE" ;;
down) compose_down "*" ;;
pull) compose_pull ;;
reboot) reboot ;;
reset-app) reset-app "$APP_NAME" ;;
reset-apps) reset-apps ;;
drop-apps) reset-app "$APP_NAME" ;;
logs) compose_logs "$PROFILE" "$SERVICES" ;;
lint) lint ;;
export) export-all ;;
import) import-all ;;
*) print_help ;;
esac
