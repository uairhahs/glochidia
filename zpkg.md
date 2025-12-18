Here is the translation of the guide for creating ZimaOS RAW packages.

Note regarding consistent naming: In the examples below, the text zimaos_terminal (and zimaos-terminal) represents the specific package name/ID. Wherever this name appears, the content must be identical (consistent) across your directory names, configuration files, and systemd service names for the package to function correctly.

Creating a RAW Package Program
Program with Backend
File Path: raw/usr/bin

Place your compiled executable result in this directory. It can be the compilation result of any program, as long as it can run on ZimaOS (x86_64/musl).

File Path: raw/usr/lib/systemd/system

Place the systemd service file corresponding to the backend program here. This is mandatory; otherwise, the backend program cannot start.

Example File: raw/usr/lib/systemd/system/zimaos-terminal.service

Ini, TOML

[Unit]
After=casaos-gateway.service
After=casaos-message-bus.service
After=casaos-user-service.service
Description=ZimaOS Chat Service

[Service]
ExecStart=/usr/bin/zimaos-terminal
Restart=always

[Install]
WantedBy=multi-user.target
Frontend Program
File Path: raw/usr/share/casaos/www/modules

Rename the dist (compilation result) of your frontend program to your package name (e.g., zimaos_terminal) and place it here.

Writing JSON Configuration
File Path: raw/usr/share/casaos/modules/zimaos_terminal.json

JSON

{
"name": "zimaos_terminal",
"ui": { // Services without a frontend do not include this section
"name": "zimaos_terminal",
"title": {
"en_us": "Terminal"
},
"prefetch": true,
"show": true,
"entry": "/modules/zimaos_terminal/index.html",
"icon": "/modules/zimaos_terminal/appicon.ico",
"description": "Assist",
"formality": {
"type": "newtab",
"props": {
"width": "100vh",
"height": "100vh",
"hasModalCard": true,
"animation": "zoom-in"
}
}
},
"services": [ // Services without a backend do not include this section
{
"name": "zimaos-terminal"
}
]  
}
Standard Systemd RAW Configuration
File Path: raw/usr/lib/extension-release.d/extension-release.zimaos_terminal

Content:

Bash

ID=\_any
Packaging
Run the following command to create the raw package:

Bash

mksquashfs raw/ zimaos_terminal.raw --no-append
Publish to App Store

1. Release Package
   Write the packaging process above into a GitHub Action. Reference: https://github.com/CorrectRoadH/ZimaOS-Terminal/blob/master/.github/workflows/release-raw.yml

Then, you must upload the result to GitHub Releases.

GitHub Action Example:

YAML

     # This is an example of uploading to GitHub Release
      - name: 'Update release'
        uses: zhanghengxin/git-release-private@ice
        with:
            token: ${{ secrets.CICD_GITHUB_TOKEN }}
            allow_override: true
            gzip: false
            tag: ${{ steps.get_version.outputs.VERSION }}
            files: ./zimaos_terminal.raw

Important: The tag for the published GitHub release must be latest. It cannot be pre-latest or draft. The GitHub Action linked in the reference above automatically applies the latest tag. If you use your own release method, please remember to implement this logic.

2. Submission (Listing)
   Modify the store registry file: https://github.com/IceWhaleTech/Mod-Store/blob/main/mod.json

JSON

    {
        "name": "zimaos_firewall",
        "title": "Zimaos Firewall",
        "repo": "CorrectRoadH/Casaos-Firewall"
        // This is the GitHub repository name where you host the release
        // https://github.com/CorrectRoadH/Casaos-Firewall
        // Use the last two parts (Owner/Repo)
    }

How Users Install
Users can manage these packages using the zpkg command line tool:

Bash

zpkg list-remote # List RAW packages available in the remote store
zpkg install <ID> # Install a package (replace <ID> with the package ID)
zpkg remove <ID> # Remove a package
zpkg list # List installed packages
Sources:

ZimaOS Terminal GitHub Repository

IceWhaleTech Mod Store
