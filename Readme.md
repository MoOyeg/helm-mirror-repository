# Bash Script to Help Mirror Helm Repositories/Charts into an OCI Compliant Registry

Bash Script that is run inside a podman container and pointed at a Helm registry to help copy a chart or a set of charts to another registry.

## Requirements
- Tested on Podman 4.2.0
- [OCI Compliant Registry for Helm](https://helm.sh/docs/topics/registries/)

## How to Run
- Build the Container Image
    ```bash
    podman build -f ./Dockerfile -t helm_mirror_tool
    ```
- Edit registry-login.sh to add your 'helm registry login' command and then copy it into the inputs folder
    ```bash
    cp registry-login.sh ./inputs
    ```

- Edit the mirror-list file to provide your mirroring configuration and then copy it into the inputs folder.
    ```bash
    cp mirror-list ./inputs
    ```

- Run the mirroring command inside a podman container. Change the 'last_n_versions' integer to select how many chart versions to mirror counting down from the most recent. Command will mount inputs folder to obtain the registry-login credentials and mirror-configuration from previous steps.

    ```bash
    podman run \
    --env mirror_list=/inputs/mirror-list \
    --env temp_dir=/mirror/tmpdir \
    --env last_n_versions=2 \
    --entrypoint /bin/bash \
    --volume ./inputs:/inputs:Z \
    localhost/helm_mirror:latest \
    -c '/inputs/registry-login.sh;/mirror/mirror.sh'
    ```