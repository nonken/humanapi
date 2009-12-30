# A simple script which recursively replaces files matching a certain string
# Because sed on OSX does not permit the -i flag we do it as we do it here

NAME=$1

BUILD_DIR=`pwd`

GIT_ROOT="$BUILD_DIR/../"
SOURCE_DIR="$BUILD_DIR/../src"
DEV_DIR="$BUILD_DIR/../dev"

ARR_REPLACE=("___PROJECTNAMEASIDENTIFIER___" "___PROJECTNAME___")
mkdir -p $DEV_DIR/$NAME/iphone
cp -R "$SOURCE_DIR/phonegap/iphone/PhoneGap-based Application/" $DEV_DIR/$NAME/iphone

# Rename files and Replace vars
cd $DEV_DIR/$NAME/iphone;

# Rename files
for key in "${ARR_REPLACE[@]}"
do
	find . -name "$key*" | sed "s/\(.*\)\($key\)\(.*\)/mv & \1$NAME\3/" | sh;

	# Replace vars within all files
	# TODO: Not sure if this is most performant =/
	for file in $(grep -l -R $key "$DEV_DIR/$NAME/iphone")
	do
		sed -e "s/$key/$NAME/g" $file > /tmp/tempfile.tmp && mv /tmp/tempfile.tmp $file
	done
done

# Move www contents
rm -Rf "$DEV_DIR/$NAME/iphone/www/"
cp -R "$SOURCE_DIR/$NAME/www/" $DEV_DIR/$NAME/iphone/www

# Copy plugins
cp -R "$SOURCE_DIR/phonegap_plugins/" $DEV_DIR/$NAME/iphone/Plugins

# Add phonegap specific icons
cp $SOURCE_DIR/$NAME/icons/Default.png $DEV_DIR/$NAME/iphone
cp $SOURCE_DIR/$NAME/icons/icon.png $DEV_DIR/$NAME/iphone