#! /bin/sh

# Script used to automatically deploy Shielding-base applications.
#
# The method used to deploy webapps into Tomcat only works reliably when the Tomcat instance is not running

#Timestamp
DATE_WITH_TIME=`date "+%Y%m%d-%H%M%S"`

echo "Executing Deployer Script----">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log

# Script parameters
ZIPS_LOCATION="$1"
CLUSTER_NAME="$2"
BJ_NAME="$3"

# Path to the gridgain installation folder
DESTINATION_PATH="/opt/gridgain"

# Contents of the ZIP files are unpacked here
TMP_WEB_CONFIG_LOCATION=$ZIPS_LOCATION/unpack/web-configurations
TMP_CONFIG_LOCATION=$ZIPS_LOCATION/unpack/configurations
TMP_LIBS_LOCATION=$ZIPS_LOCATION/unpack/dependencies

# Final target locations where the ZIP files' content will be copied to
WEB_CONFIG_LOCATION=$DESTINATION_PATH/tomcat
CONFIG_LOCATION=$DESTINATION_PATH/$CLUSTER_NAME/config
LIBS_LOCATION=$DESTINATION_PATH/$CLUSTER_NAME/libs
WEBAPPS_LOCATION=$DESTINATION_PATH/tomcat/webapps

extract() {
    if [ ! -d "$ZIPS_LOCATION" ]; then
        echo "The specified folder does NOT exist. Aborting.">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
        return 1
    fi

    echo "Cleaning up unpack folder (if it exists)">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
    rm -fr "$ZIPS_LOCATION/unpack"
    mkdir -p $TMP_WEB_CONFIG_LOCATION
    mkdir -p $TMP_CONFIG_LOCATION
    mkdir -p $TMP_LIBS_LOCATION

    isempty=$(ls "${ZIPS_LOCATION}" | wc -l)
    if [ "$isempty" -gt 0 ]; then
        for entry in ${ZIPS_LOCATION}/*; do
            filename=$(basename "$entry")
            if [[ $filename == "unpack" ]]; then
                continue
            elif [[ $filename == *"tomcat-config.zip" ]]; then
                echo ">>>>>> Unpack $filename">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
                unzip -qq -o $entry -d $TMP_WEB_CONFIG_LOCATION
                deployWebConfig
            elif [[ $filename == *"config.zip" ]]; then
                echo ">>>>>> Unpack $filename">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
                unzip -qq -o $entry -d $TMP_CONFIG_LOCATION
                deployConfig
            elif [[ $filename == *"dependencies.zip" ]]; then
                echo ">>>>>> Unpack $filename">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
                unzip -qq -o $entry -d $TMP_LIBS_LOCATION
                deployDependencies
            fi
        done
    fi
}

deployWebConfig() {
    if [ -d "$TMP_WEB_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat/" ]; then
        echo "Copying $TMP_WEB_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat/ content to $WEB_CONFIG_LOCATION">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
        cp -rv $TMP_WEB_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat/* $WEB_CONFIG_LOCATION/
    else
        echo "WARNING: Folder $TMP_WEB_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat/ not found!">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
    fi
}

deployConfig() {
    if [ -d "$TMP_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/" ]; then
        if [ -d "$CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/" ]; then
            echo "Replacing following CONFIG folder: $CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
            rm -r $CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/
        else
            echo "Creating following LIBS folder: : $CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
        fi

        cp -r $TMP_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME $CONFIG_LOCATION/
    else
        echo "WARNING: Folder $TMP_CONFIG_LOCATION/$CLUSTER_NAME-$BJ_NAME/ not found!">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
    fi
}

deployDependencies() {
    if [ -d "$TMP_LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME/" ]; then
        deployLibs
    fi

    if [ -d "$TMP_LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat/" ]; then
        deployWebapp
    fi
}

deployLibs() {
    if [ -d "$LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME/" ]; then
        echo "Replacing following LIBS folder: $LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
        rm -r $LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME
    else
        echo "Creating following LIBS folder: $LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log
    fi

    cp -r $TMP_LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME $LIBS_LOCATION/
    grantPermissions "$LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME"
}

grantPermissions() {
    chmod -R 750 $1
}

deployWebapp() {
    TMP_WEBAPPS_LOCATION=$TMP_LIBS_LOCATION/$CLUSTER_NAME-$BJ_NAME-tomcat

    isempty=$(ls "${TMP_WEBAPPS_LOCATION}" | wc -l)
    if [ "$isempty" -gt 0 ]; then
        for entry in ${TMP_WEBAPPS_LOCATION}/*; do
            filename=$(basename "$entry")
            warname="${filename%.*}"

            echo "Deploying $filename to $WEBAPPS_LOCATION">> /opt/gridgain/logs/shielding/nolioDeployment$DATE_WITH_TIME.log

            # remove WAR (if it exists)
            rm -f "$WEBAPPS_LOCATION/$filename"

            # remove unpacked WAR folder (if it exists)
            rm -rf "$WEBAPPS_LOCATION/$warname/"

            # Do the copy
            cp -r $TMP_WEBAPPS_LOCATION/$filename $WEBAPPS_LOCATION
        done
    else
        echo "No files to be deployed found in ${TMP_WEBAPPS_LOCATION}"
    fi
}

extract

