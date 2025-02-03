#!/bin/bash

DEFAULT_UID='1000'

function prompt_proxy {
    read -p "Are you behind a proxy that you want to configure now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\nPlease provide your HTTP_PROXY URL (e.g. http://proxy.example.com:8080):"
        read -r HTTP_PROXY
        echo -e "\nPlease provide your HTTPS_PROXY URL (often the same as HTTP_PROXY):"
        read -r HTTPS_PROXY
        echo -e "\nPlease provide your NO_PROXY list (default: localhost,127.0.0.1,::1):"
        read -r NO_PROXY
        [ -z "$NO_PROXY" ] && NO_PROXY="localhost,127.0.0.1,::1"

        echo -e "\nWriting proxy configuration to /etc/proxy.conf..."
        echo "HTTP_PROXY=$HTTP_PROXY" | sudo tee /etc/proxy.conf > /dev/null
        echo "HTTPS_PROXY=$HTTPS_PROXY" | sudo tee -a /etc/proxy.conf > /dev/null
        echo "NO_PROXY=$NO_PROXY" | sudo tee -a /etc/proxy.conf > /dev/null

        echo -e "\nConfiguring system-wide proxy using proxyman..."
        SUDO_USER=clab SUDO_UID=1000 SUDO_GID=1000 sudo proxyman set > /dev/null 2>&1
        echo -e "\nProxy has been set. You can run 'sudo proxyman unset' to remove it."
        eval "$(sudo /usr/local/bin/proxyman export)"
        echo -e "\n\033[32mWelcome to Containerlab's WSL distribution\033[0m"
    else
        echo -e "\nSkipping proxy configuration.\n"
    fi
}

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

        # Install fonts using PowerShell
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
        echo -e "\033[33mNote: You may need to restart Windows Terminal to see the new fonts.\033[0m"
    fi
}

function import_ssh_keys {
    KEY_CHECK=$(powershell.exe -NoProfile -Command '
        $key_types = @("rsa", "ecdsa", "ed25519")

        foreach ( $type in $key_types )
        {
            if( Test-Path $env:userprofile\.ssh\id_$type.pub )
            {
                return $type
            }
        }
        Write-Output False
    ')

    mkdir -p /home/clab/.ssh

    case $KEY_CHECK in
        rsa*)
            KEY=$(powershell.exe -NoProfile -Command 'Get-Content $env:userprofile\.ssh\id_rsa.pub')
            echo $KEY | sudo tee -a /home/clab/.ssh/authorized_keys > /dev/null
            ;;
        ecdsa*)
            KEY=$(powershell.exe -NoProfile -Command 'Get-Content $env:userprofile\.ssh\id_ecdsa.pub')
            echo $KEY | sudo tee -a /home/clab/.ssh/authorized_keys > /dev/null
            ;;
        ed25519*)
            KEY=$(powershell.exe -NoProfile -Command 'Get-Content $env:userprofile\.ssh\id_ed25519.pub')
            echo $KEY | sudo tee -a /home/clab/.ssh/authorized_keys > /dev/null
            ;;
        False*)
            powershell.exe -NoProfile -Command "ssh-keygen -t rsa -b 4096 -f \$env:userprofile\.ssh\id_rsa -N ''" > /dev/null 2>&1
            KEY=$(powershell.exe -NoProfile -Command 'Get-Content $env:userprofile\.ssh\id_rsa.pub')
            echo $KEY | sudo tee -a /home/clab/.ssh/authorized_keys > /dev/null
            ;;
        *)
            echo -e "\033[34m\nSSH: Could not detect key type. Please check or create a key.\033[0m"
    esac

    echo -e "\033[32mSSH keys successfully copied. You can SSH into Containerlab WSL passwordless with: 'ssh clab@localhost -p 2222' (Ensure Containerlab WSL is open)\033[0m"
}

### CONTAINERLAB COMPLETIONS ###
function install_clab_completions_bash {
    echo "Installing Containerlab completions for BASH..."

    mkdir -p /etc/bash_completion.d
    containerlab completion bash > /etc/bash_completion.d/containerlab

    # Also enable completions for the 'clab' alias
    {
        echo ""
        echo "# Also autocomplete for 'clab' alias"
        echo "complete -o default -F __start_containerlab clab"
    } >> /etc/bash_completion.d/containerlab
}

function install_clab_completions_zsh {
    echo "Installing Containerlab completions for ZSH..."

    # oh-my-zsh custom completions directory
    local ZSH_COMPLETIONS_DIR="/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions"

    # Make sure directory exists
    mkdir -p "$ZSH_COMPLETIONS_DIR"

    containerlab completion zsh > "${ZSH_COMPLETIONS_DIR}/_containerlab"

    # Include 'clab' alias in the compdef
    sed -i 's/compdef _containerlab containerlab/compdef _containerlab containerlab clab/g' \
        "${ZSH_COMPLETIONS_DIR}/_containerlab"

    chown clab:clab "${ZSH_COMPLETIONS_DIR}/_containerlab"
}

# Start OOBE logic
echo -e "\033[32mWelcome to Containerlab's WSL distribution\033[0m"
echo "cd ~" >> /home/clab/.bashrc
echo "echo clab | sudo -S mkdir -p /run/docker/netns" >> /home/clab/.bashrc

# Check connectivity before anything else
if ! curl -fsSL --connect-timeout 5 https://www.google.com -o /dev/null; then
    echo -e "\nIt seems we couldn't connect to the internet directly. You might be behind a proxy."
    prompt_proxy
fi

PS3="

Please select which shell you'd like to use: "
shell_opts=("zsh" "bash with two-line prompt" "bash (default WSL prompt)")
select shell in "${shell_opts[@]}"
do
    case $shell in
        "zsh")
            echo -e "\033[34m\nzsh selected\033[0m"
            echo -e "\033[33mNote: zsh with custom theme requires Nerd Font for proper symbol display.\033[0m"

            PS3="

Select zsh configuration: "
            zsh_opts=("Full featured (many plugins)" "Lean version (minimal plugins)")
            select zsh_config in "${zsh_opts[@]}"
            do
                case $zsh_config in
                    "Full featured (many plugins)")
                        echo -e "\033[34m\nConfiguring full featured zsh\033[0m"
                        read -p "Would you like to install FiraCode Nerd Font? (y/N) " -n 1 -r
                        echo
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            install_fonts
                        fi
                        sudo -u clab cp /home/clab/.zshrc{,.bak}
                        sudo -u clab cp /home/clab/.p10k.zsh{,.bak}
                        break 2
                        ;;
                    "Lean version (minimal plugins)")
                        echo -e "\033[34m\nConfiguring lean zsh\033[0m"
                        read -p "Would you like to install FiraCode Nerd Font? (y/N) " -n 1 -r
                        echo
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            install_fonts
                        fi
                        sudo -u clab cp /home/clab/.zshrc{,.bak}
                        sudo -u clab cp /home/clab/.p10k.zsh{,.bak}
                        sudo -u clab cp /home/clab/.zshrc-lean /home/clab/.zshrc
                        sudo -u clab cp /home/clab/.p10k-lean.zsh /home/clab/.p10k.zsh
                        break 2
                        ;;
                    *)
                        echo -e "\033[31m\n'$REPLY' is not a valid choice\033[0m"
                        ;;
                esac
            done

            sudo chsh -s "$(which zsh)" clab

            # Install Containerlab completions for zsh
            install_clab_completions_zsh
            break
            ;;

        "bash with two-line prompt")
            echo -e "\033[34m\nbash with two-line prompt selected.\033[0m"
            read -p "Would you like to install FiraCode Nerd Font? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_fonts
            fi
            # Backup .bashrc
            sudo -u clab cp /home/clab/.bashrc /home/clab/.bashrc.bak
            sudo chsh -s "$(which bash)" clab
            setup-bash-prompt

            # Install Containerlab completions for bash
            install_clab_completions_bash
            break
            ;;

        "bash (default WSL prompt)")
            echo -e "\033[34m\nbash selected\033[0m"
            sudo chsh -s "$(which bash)" clab

            # Install Containerlab completions for bash
            install_clab_completions_bash
            break
            ;;

        *)
            echo -e "\033[31m\n'$REPLY' is not a valid choice\033[0m"
            ;;
    esac
done

import_ssh_keys
exit 0
