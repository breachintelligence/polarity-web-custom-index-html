# Polarity Web Custom-Script Injector v1.0.0

A Bash utility that lets you inject your own JavaScript into the _index.html_ shipped inside Polarity Web’s Docker image and bind-mount the modified assets into your running stack.  Useful for cases where a customer needs to run custom tracking or agent code in the web application.

---

## Table of Contents
1. [Features](#features)
2. [Prerequisites](#prerequisites)
3. [Usage](#usage)

---

## Features
* Lists local Docker images whose **repository** contains `web` and helps you pick one.
* Validates the selected image actually exists (`docker image inspect`).
* Prompts for the JavaScript file to inject (defaults to `script.js`).
* Copies _/usr/share/caddy_ out of the image into `/tmp`.
* Injects your script just after `<head>` in _index.html_.
* Copies the modified assets to `/app/polarity-web-modified`.
* Prints the `docker-compose.yml` volume snippet and SELinux relabel command you need.
* Cleans up all temporary artefacts.

---

## Prerequisites
| Requirement | Notes |
|-------------|-------|
| Bash 4+     | Uses `mapfile` and here-strings. |
| Docker 19+  | Needs permission to run `docker images`, `docker create`, `docker cp`, etc. |
| Local Polarity Web image | Usually tagged `…/web:<version>`. |
| SELinux users | The `:z` flag and `chcon` command apply when SELinux is enforcing. |

---

## Usage

1. Copy the script somewhere in your PATH:
```bash
cp copy-polarity-web.sh /home/<user>
```

Alternatively, clone this repository into your user directory

> Replace {{user}} with your user directory 
```
cd /home/{{user}}
git clone https://github.com/breachintelligence/polarity-web-custom-index-html.git
cd polarity-web-custom-index-html
```

2. Make the `copy-polarity-web.sh` script executable:
```bash
chmod +x copy-polarity-web.sh
```

3. Place your custom JavaScript (default: script.js) in the same directory or supply another path when prompted.


4. Run it:
```bash
./copy-polarity-web.sh
```

5. Edit /app/docker-compose.yml and add the bind-mount:
```bash
services:
  web:            
    volumes:
      - /app/polarity-web-modified:/usr/share/caddy:z
```

6. Restart the stack: 

```bash
cd /app && ./down.sh && ./up.sh
```

7. If selinux is enabled and in enforcing mode you may need to run the following:

```bash
sudo chcon -Rt svirt_sandbox_file_t /app/polarity-web-modified
```

8. Re-run the script anytime Polarity Web is updated.  Modifying the `docker-compose.yml` should be a one-time operation unless the compose file has been overwritten.

## In Script Configuration Variables

The following configuration variables are used by the script.  In most cases you will not need to change these defaults.

```
# default JS source file
SCRIPT_FILE="script.js"                   

# host dir for patched assets
VOLUME_PATH="/app/polarity-web-modified"  

# Temp container name when copying current web container content
TEMP_CONTAINER_NAME="polarity-web-app-script-injected-temp"

# Temp location to write container content to before modifying `index.html` file
TMP_DIR="/tmp/polarity-web-tmp"
```

If you need to modify one of the variables you can do so by editing the value at the top of the `copy-polarity-web.sh` file. 


