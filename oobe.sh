#!/bin/bash

set -ue

DEFAULT_UID='1000'

function setup-bash-prompt {
    # Check if the prompt is already set up
    if grep -q "function promptcmd" /home/clab/.bashrc; then
        echo "Bash prompt already configured in .bashrc"
        return 1
    fi

    cat << 'EOF' >> /home/clab/.bashrc

# Custom Bash Prompt Configuration
WHITE='\[\033[1;37m\]'; LIGHTRED='\[\033[1;31m\]'; LIGHTGREEN='\[\033[1;32m\]'; LIGHTBLUE='\[\033[1;34m\]'; DEFAULT='\[\033[0m\]'
cLINES=$WHITE; cBRACKETS=$WHITE; cERROR=$LIGHTRED; cSUCCESS=$LIGHTGREEN; cHST=$LIGHTGREEN; cPWD=$LIGHTBLUE; cCMD=$DEFAULT
promptcmd() { 
    PREVRET=$?
    PS1="\n"
    if [ $PREVRET -ne 0 ]; then 
        PS1="${PS1}${cBRACKETS}[${cERROR}x${cBRACKETS}]${cLINES}\342\224\200"
    else 
        PS1="${PS1}${cBRACKETS}[${cSUCCESS}*${cBRACKETS}]${cLINES}\342\224\200"
    fi
    PS1="${PS1}${cBRACKETS}[${cHST}\h${cBRACKETS}]${cLINES}\342\224\200"
    PS1="${PS1}[${cPWD}\w${cBRACKETS}]"
    PS1="${PS1}\n${cLINES}\342\224\224\342\224\200\342\224\200> ${cCMD}"
}
PROMPT_COMMAND=promptcmd
EOF

}

function install_fonts {
    echo -e "\033[34m\nInstalling FiraCode Nerd Font...\033[0m"

    # Font name pattern to match any FiraCode Nerd Font variant
    FONT_NAME_PATTERN='FiraCode Nerd Font*'

    # Check if any FiraCode Nerd Font is already installed using PowerShell
    FONT_CHECK=$(powershell.exe -NoProfile -Command '
        Add-Type -AssemblyName System.Drawing
        $fonts = [System.Drawing.Text.InstalledFontCollection]::new().Families
        $fontNamePattern = "'"$FONT_NAME_PATTERN"'"
        $found = $fonts | Where-Object { $_.Name -like $fontNamePattern } | Select-Object -First 1
        if ($found) { "yes" } else { "no" }
    ')

    if [[ "$FONT_CHECK" =~ "yes" ]]; then
        echo -e "\033[33mFiraCode Nerd Font is already installed. Skipping installation.\033[0m"
    else
        echo "Downloading FiraCode Nerd Font..."
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        curl -fLo "FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip

        # Unzip the font files
        unzip -q FiraCode.zip -d FiraCodeNF

        # Convert the path to Windows format
        FONTS_PATH=$(wslpath -w "$TMP_DIR/FiraCodeNF")

        # Install fonts using PowerShell directly with ExecutionPolicy set to Bypass
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
            $fontFiles = Get-ChildItem -Path "'"$FONTS_PATH"'" -Filter "*.ttf"
            foreach ($fontFile in $fontFiles) {
                $shellApp = New-Object -ComObject Shell.Application
                $fontsFolder = $shellApp.NameSpace(0x14)
                $fontsFolder.CopyHere($fontFile.FullName, 16)
            }
        '

        # Clean up
        cd ~
        rm -rf "$TMP_DIR"

        echo -e "\033[32mFiraCode Nerd Font installed successfully.\033[0m"
        echo -e "\033[33mNote: You may need to restart Windows Terminal to see the new fonts in the font selection.\033[0m"
    fi
}

# We know the user clab exists from Dockerfile with UID 1000
if getent passwd "$DEFAULT_UID" > /dev/null ; then

    echo -e "\033[32mWelcome to Containerlab's WSL distribution\033[0m"

    echo "cd ~" >> /home/clab/.bashrc

    PS3="
Please select which shell you'd like to use: "

    shell_opts=("zsh" "bash with two-line prompt" "bash (default WSL prompt)")
    select shell in "${shell_opts[@]}"
    do
        case $shell in
            "zsh")
                echo -e "\033[34m\nzsh selected\033[0m"
                echo -e "\033[33mNote: zsh with custom theme requires Nerd Font for proper symbol display\033[0m"
                read -p "Would you like to install FiraCode Nerd Font? (y/N) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    install_fonts
                fi
                sudo chsh -s "$(which zsh)" clab
                break
                ;;
            "bash with two-line prompt")
                echo -e "\033[34m\nbash with two-line prompt selected. Configuring two-line prompt\033[0m"
                read -p "Would you like to install FiraCode Nerd Font? (y/N) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    install_fonts
                fi
                # Backup .bashrc
                sudo -u clab cp /home/clab/.bashrc /home/clab/.bashrc.bak
                sudo chsh -s "$(which bash)" clab
                setup-bash-prompt
                break
                ;;
            "bash (default WSL prompt)")
                echo -e "\033[34m\nbash selected\033[0m"
                sudo chsh -s "$(which bash)" clab
                break
                ;;
            *) echo -e "\033[31m\n'$REPLY' is not a valid choice\033[0m";;
        esac
    done

    #containerlab version

    exit 0
fi

# This part will (should) never be reached since clab user exists,
# but keeping it as a fallback
echo 'No user account detected, Something may be wrong with your installation. Create an issue at <githubIssueLink>'
exit 1