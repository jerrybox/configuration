#!/bin/bash
## win10 wsl 下运行的脚本

mkdir -p logs
log_file=logs/install-$(date +%Y%m%d-%H%M%S).log
exec > >(tee $log_file) 2>&1
echo "Capturing output to $log_file"
echo "Installation started at $(date '+%Y-%m-%d %H:%M:%S')"

function finish {
    echo "Installation finished at $(date '+%Y-%m-%d %H:%M:%S')"
}
trap finish EXIT

## moso custom configuration
OPENEDX_RELEASE="open-release/hawthorn.2"
CONFIGURATION_REPO="https://github.com/jerrybox/configuration.git"
CONFIGURATION_VERSION="mosoDEV"
EDX_PLATFORM_REPO="https://github.com/jerrybox/MOSOEDU.git"
EDX_PLATFORM_VERSION="mosoDEV"
master_host="192.168.56.13"
slave_host="192.168.56.16"

echo "Installing release '$OPENEDX_RELEASE'"
##
## Overridable version variables in the playbooks. Each can be overridden
## individually, or with $OPENEDX_RELEASE.
##
VERSION_VARS=(
    edx_platform_repo
    edx_platform_version
    certs_version
    forum_version
    xqueue_version
    configuration_repo
    configuration_version
    demo_version
    NOTIFIER_VERSION
    INSIGHTS_VERSION
    ANALYTICS_API_VERSION
    ECOMMERCE_VERSION
    ECOMMERCE_WORKER_VERSION
    DISCOVERY_VERSION
    THEMES_VERSION
)

for var in ${VERSION_VARS[@]}; do
    # Each variable can be overridden by a similarly-named environment variable,
    # or OPENEDX_RELEASE, if provided.
    ENV_VAR=$(echo $var | tr '[:lower:]' '[:upper:]')
    eval override=\${$ENV_VAR-\$OPENEDX_RELEASE}
    if [ -n "$override" ]; then
        EXTRA_VARS="-e $var=$override $EXTRA_VARS"
    fi
done

# my-passwords.yml is the file made by generate-passwords.sh.
if [[ -f my-passwords.yml ]]; then
    EXTRA_VARS="-e@$(pwd)/my-passwords.yml $EXTRA_VARS"
fi

CONFIGURATION_VERSION=${CONFIGURATION_VERSION-$OPENEDX_RELEASE}

source /root/venv2/bin/activate

##
## Run the edx_sandbox.yml playbook in the configuration/playbooks directory
##
cd playbooks && ansible-playbook -c local ./moso_edxapp.yml -i "$slave_host," $EXTRA_VARS "$@"
ansible_status=$?

if [[ $ansible_status -ne 0 ]]; then
    echo " "
    echo "========================================"
    echo "Ansible failed!"
    echo "----------------------------------------"
    echo "If you need help, see https://open.edx.org/getting-help ."
    echo "When asking for help, please provide as much information as you can."
    echo "These might be helpful:"
    echo "    Your log file is at $log_file"
    echo "    Your environment:"
    env | egrep -i 'version|release' | sed -e 's/^/        /'
    echo "========================================"
fi
