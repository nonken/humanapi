# A simple script which recursively replaces files matching a certain string
# Because sed on OSX does not permit the -i flag we do it as we do it here

DIR=$1
SEARCH_PHRASE=$2
REPLACE_PHRASE=$3

for file in $(grep -l -R $SEARCH_PHRASE $DIR)
	do
		sed -e "s/$SEARCH_PHRASE/$REPLACE_PHRASE/g" $file > /tmp/tempfile.tmp && mv /tmp/tempfile.tmp $file
done