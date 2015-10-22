#!/bin/bash -x

# You need to set following environment variables.
# NIFTY_ACCESS_KEY_ID
# NIFTY_SECRET_KEY
# NIFTY_CLOUD_STORAGE_ACCESS_KEY_ID
# NIFTY_CLOUD_STORAGE_SECRET_KEY
# NIFTY_CLOUD_STORAGE_BACKET_NAME
# NIFTY_ZONE
# NIFTY_FW_GROUP
# COREOS_CHANNEL
# SUFFIX

WORKDIR=$(pwd)

if [ "$COREOS_CHANNEL" == "" ] ; then
  echo "You need to set COREOS_CHANNEL"
  exit 0
fi

if [ "$COREOS_VERSION" == "" ] ; then
  COREOS_VERSION=current
fi

# Make temp dir
DIR=$(mktemp -d)
cp -p init.sh $DIR/
pushd $DIR

# Install NIFTY Cloud CLI
wget -q http://cloud.nifty.com/api/sdk/NIFTY_Cloud_api-tools.zip
unzip NIFTY_Cloud_api-tools.zip
rm -f NIFTY_Cloud_api-tools.zip
rm -rf NIFTY_Cloud_api-tools/bin/*.cmd
chmod +x NIFTY_Cloud_api-tools/bin/*
export NIFTY_CLOUD_HOME=$(pwd)/NIFTY_Cloud_api-tools/
export PATH=${PATH}:${NIFTY_CLOUD_HOME}/bin

# Check if NIFTY Cloud is in maintenance.
NIFTYCLOUD_STATUS=$(nifty-describe-service-status)
if [ "$(echo "${NIFTYCLOUD_STATUS}"|grep "Service.Maintenance")" ]; then
    echo "MESSAGE = NIFTY Cloud is in maintenance." > "$WORKDIR/msg.prop"
    exit 1
fi

# Install NIFTY Cloud Storage CLI
wget -q http://cloud.nifty.com/api/storage/NiftyCloudStorage-SDK-CLI.zip
unzip NiftyCloudStorage-SDK-CLI.zip
rm -f NiftyCloudStorage-SDK-CLI.zip
chmod +x NiftyCloudStorage-SDK-CLI/ncs_cli.sh
sed -i "s/accessKey =/accessKey = ${NIFTY_CLOUD_STORAGE_ACCESS_KEY_ID}/" credentials.properties
sed -i "s/secretKey =/secretKey = ${NIFTY_CLOUD_STORAGE_SECRET_KEY}/" credentials.properties

# Download and check CoreOS Image for NIFTY Cloud
BASE_URL=http://${COREOS_CHANNEL,,}.release.core-os.net/amd64-usr/$COREOS_VERSION
VERSION_TXT=version.txt
VERSION_TXT_SIG=version.txt.sig
OVF=coreos_production_niftycloud.ovf
OVF_SIG=coreos_production_niftycloud.ovf.sig
VMDK_BZ2=coreos_production_niftycloud_image.vmdk.bz2
VMDK_BZ2_SIG=coreos_production_niftycloud_image.vmdk.bz2.sig

# Import CoreOS Image Signing Key
curl https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.pem | gpg --import -

# Download version.txt
wget -q ${BASE_URL}/${VERSION_TXT}
wget -q ${BASE_URL}/${VERSION_TXT_SIG}
gpg --verify ${VERSION_TXT_SIG}

VERSION=$(grep 'COREOS_VERSION=' ${VERSION_TXT} | awk -F'=' '{print $2}')
IMAGE_NAME="CoreOS ${COREOS_CHANNEL} ${VERSION}${SUFFIX}"

echo "CoreOS Version: $VERSION"

# Check NIFTY Cloud CoreOS Version
nifty-describe-images --delimiter ',' --image-name "${IMAGE_NAME}" | grep "${IMAGE_NAME}"
if [ $? -eq 0 ] ; then
    echo "MESSAGE = ${IMAGE_NAME} is already released." > "$WORKDIR/msg.prop"
    exit 0
fi

# Download OVF and VMDK
wget -q ${BASE_URL}/${OVF}
wget -q ${BASE_URL}/${OVF_SIG}
gpg --verify ${OVF_SIG}
wget -q ${BASE_URL}/${VMDK_BZ2}
wget -q ${BASE_URL}/${VMDK_BZ2_SIG}
gpg --verify ${VMDK_BZ2_SIG}

bunzip2 ${VMDK_BZ2}
VMDK="coreos_production_niftycloud_image.vmdk"

echo "Importing the ovf..."
INSTANCE_ID=$(nifty-import-instance ${VMDK} -t mini -V ${OVF} -g ${NIFTY_FW_GROUP} -z ${NIFTY_ZONE} -q POST | grep "IMPORTINSTANCE" | awk '{print $4}')
echo "done."

# Wait until the instance status is running
get_instance_status() {
    INSTANCE_ID=$1
    STATUS=$(nifty-describe-instances ${INSTANCE_ID} --delimiter ',' | grep 'INSTANCE' | awk -F',' '{print $6}' | tr -d '\n' | tr -d '\r')
    echo ${STATUS}
}

echo "Check status of the instance.."
STATUS=$(get_instance_status ${INSTANCE_ID})
echo ${STATUS}
while [ "${STATUS}" != "running" ]; do
    sleep 10
    STATUS=$(get_instance_status ${INSTANCE_ID})
    echo ${STATUS}
    if [ "${STATUS}" == "import_error" ]; then
        exit 1
    fi
done

# Reboot and execute startup script to remove machine-id
echo "Reboot the instance.."
nifty-reboot-instances ${INSTANCE_ID} -q POST --user-data-file-plain init.sh
sleep 10
STATUS=$(get_instance_status ${INSTANCE_ID})
echo ${STATUS}
while [ "${STATUS}" != "running" ]; do
    sleep 10
    STATUS=$(get_instance_status ${INSTANCE_ID})
    echo ${STATUS}
done

echo "Stop the instance.."
nifty-stop-instances ${INSTANCE_ID}
STATUS=$(get_instance_status ${INSTANCE_ID})
echo ${STATUS}
while [ "${STATUS}" != "stopped" ]; do
    sleep 10
    STATUS=$(get_instance_status ${INSTANCE_ID})
    echo ${STATUS}
done
echo "done."

# Create an image and wait until the image status is available
get_image_status() {
    IMAGE_ID=$1
    STATUS=$(nifty-describe-images ${IMAGE_ID} --delimiter ',' | awk -F',' '{print $6}' | tr -d '\n' | tr -d '\r')
    echo ${STATUS}
}
echo "Create image..."
IMAGE_ID=$(nifty-create-image ${INSTANCE_ID} --name "${IMAGE_NAME}" --left-instance false | awk '{print $2}')
STATUS=$(get_image_status ${IMAGE_ID})
while [ "${STATUS}" != "available" ]; do
    sleep 10
    STATUS=$(get_image_status ${IMAGE_ID})
done
echo "done."

# Get and upload CoreOS icon
pushd NiftyCloudStorage-SDK-CLI
./ncs_cli.sh get ncss://niftycloud-control-panel/master/coreos.png coreos.png
./ncs_cli.sh put coreos.png ncss://niftycloud-control-panel/icon/${IMAGE_ID}
popd

popd
rm -rf $DIR
echo "MESSAGE = ${IMAGE_NAME} is available on NIFTY Cloud!" > "$WORKDIR/msg.prop"
