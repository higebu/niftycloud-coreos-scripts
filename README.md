# niftycloud-coreos-scripts

Scripts for importing CoreOS images to NIFTY Cloud as public images.

CoreOS images are imported to NIFTY Cloud automatically using this scripts with Travis CI and NIFTY Cloud Timer.

Build status: [![Build Status](https://travis-ci.org/higebu/niftycloud-coreos-scripts.svg?branch=master)](https://travis-ci.org/higebu/niftycloud-coreos-scripts)

`passed` means new version of CoreOS image(s) is(are) released, `failed` means there is(are) no new version of CoreOS image(s).

## Usage

Set environment variables and run following command:

```
./import_coreos.sh
```

## Environment variables

### Required:

* `COREOS_CHANNEL` - CoreOS channel. Alpha, Beta or Stable.
* `NIFTY_ACCESS_KEY_ID` - NIFTY Cloud API Access Key ID
* `NIFTY_SECRET_KEY` -  NIFTY Cloud API Secret Key
* `NIFTY_ZONE` - Zone for importing CoreOS VMs.
* `NIFTY_FW_GROUP` - Firewall group for importing CoreOS VMs.
* `NIFTY_CLOUD_STORAGE_ACCESS_KEY_ID` - NIFTY Cloud API Access Key ID for uploading icon image.
* `NIFTY_CLOUD_STORAGE_SECRET_KEY` - NIFTY Cloud Storage API Secret Key for uploading icon image.
* `NIFTY_CLOUD_STORAGE_BACKET_NAME` - NIFTY Cloud Storage backet name for uploading icon image.

### Optional:

* `SUFFIX` - Suffix of image name for testing.

## TODO

* Publish images automatically.
