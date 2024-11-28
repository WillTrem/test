## About this repository

This repository provides the base structure for building an app, meant to be duplicated when creating a new app with the adaptive-ui platform.

## Initial setup for linux users

If you are using this repository on linux, some permissions needs to be setup in order for the `apps` and `configs` directories to behave properly. This can be done by running the following script:

```bash
./main.sh init
```

You will be prompted to enter your sudo password. This is to be able to make changes to the permissions and ownership of the `apps` and `configs` directories.

After the initialization has been done, you'll have to close and re-open all VSCode (or other IDE) pages for the change to take effects. Simply reloading the VSCode window will not work.

## Script execution

Any command or script execution should go through `./main.sh [--profile PROFILE] <COMMAND> `.
Here are the available commands:

- `init`: Sets up permissions for access to local folders mounted as docker volumes. Should only be ran once.
- `up` : Start all services using the specified profile (default: dev)
- `down` : Stop all services
- `pull` : Pull the latest images
- `logs` : Follow the logs of the services (optionally specify services as csv)
- `reset` : Resets everything in the database except the users
- `reset-app` <app_name> : Reset only an application and its data
- `reset-apps` : Reset all the applications and their data
- `export` : Exports the app configuration and translation data to files in `./configs/`
- `import` : Imports the app configuration and translation data from files in `./configs/`

> Note that it is required to run the commands in a bash environment. Otherwise, they might not work as intended.
