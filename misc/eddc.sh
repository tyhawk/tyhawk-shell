#!/usr/bin/env bash
#
# Elite Dangerous data copier
####################################

# Enabling colours
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)

# Folders
edlogtarget="${HOME}/elitedata/"
edlogtargetlog="${edlogtarget}logs/"
edlogtargetimg="${edlogtarget}images/"
bkphost="raven.birdsnest.lan"
bkpfolder="/mnt/Backup/EliteDangerousFlightLogs/"
imgfolder='/Pictures/Frontier Developments/Elite Dangerous'

gfcheck() {
	if [[ "$?" -eq 0 ]]
	then
		printf "${GREEN}OK${NORMAL}\n"
	else
		printf "${RED}FAIL${NORMAL}\n"
	fi
}

# Header
printf "${BLUE}..:: Elite Dangerous log & image copier ::..${NORMAL}\n"

# Create dir if it doesn't exist
if [[ ! -d "$edlogtarget" ]]
then
	mkdir -p $edlogtarget{logs,images}
fi

# Step 1 - Check verbise logging
printf "\n${BLUE}Checking if verbose logging has been enabled: ${NORMAL}"
vlog=$( grep VerboseLogging '/Users/jgerritse/Library/Application Support/Steam/steamapps/common/Elite Dangerous/Products/FORC-FDEV-D-1010/EliteDangerous.app/Contents/Resources/AppConfig.xml' | wc -l )
if [[ "$vlog" -eq 1 ]]
then
    printf "${GREEN}YES${NORMAL}\n"
elif [[ "$vlog" -eq 0 ]]
then
    printf "${RED}NO${NORMAL}\n"
else
    printf "${YELLOW}FAIL${NORMAL}\n"
fi

# Step 2 - Backup of the key bindings
printf "\n${BLUE}Making a backup copy of the key bindings file: ${NORMAL}"
cp '/Users/jgerritse/Library/Application Support/Frontier Developments/Elite Dangerous/Options/Bindings/Custom.1.8.binds' ${edlogtarget}Custom.1.8.binds-$(date +%y%m%d)
gfcheck

# Step 3 - Copy and process the logs
printf "\n${BLUE}Copy all logs to the elitelogs directory${NORMAL}\n"
# First delete de debuglogs
find '/Users/jgerritse/Library/Application Support/Frontier Developments/Elite Dangerous/Logs/' -type f -name 'debugOutput*log' -delete
# Then copy the rest
rsync --archive --progress '/Users/jgerritse/Library/Application Support/Frontier Developments/Elite Dangerous/Logs/' $edlogtargetlog
# Make sure I keep my logs for safekeeping
printf "\n${BLUE}Upload logs and images to the backup folder on the SAN${NORMAL}\n"
rsync --archive --progress --exclude '.DS_Store' --exclude 'Screenshot*' --delete $edlogtarget $bkphost:$bkpfolder
# Remove any files older than 14 days from the ED log dir
printf "\n${BLUE}Purge old logs from the Elite Dangerous log directory${NORMAL}\n"
find '/Users/jgerritse/Library/Application Support/Frontier Developments/Elite Dangerous/Logs/' -type f -mtime +30 -delete
gfcheck

# Step 4 - Copy the screenshots. They may need further processing / renaming
printf "\n${BLUE}Move new images to the elitelogs directory for further processing${NORMAL}\n"
rsync --archive --progress '/Users/jgerritse/Pictures/Frontier Developments/Elite Dangerous/' $edlogtargetimg
if [[ "$?" -eq 0 ]]
then
	find '/Users/jgerritse/Pictures/Frontier Developments/Elite Dangerous/' -type f -name '*bmp' -delete
fi
# Converting the images
printf "\n${BLUE}Converting images to png${NORMAL}\n"
for image in $(find $edlogtargetimg -name '*bmp')
do
	if [[ -z "$image" ]]
	then
		printf "Nothing to do.\n"
	else
		# Determine the filename
		#imagename=$(basename $image | sed 's/\.[^.]*$//')
		imagename="ZZ-Screenshot-$(date +%y%m%d-%H%M%S)"
		printf " Processing $image: "
		sips -s format png $image --out ${edlogtargetimg}/${imagename}.png >/dev/null 2>&1
		if [[ "$?" -eq 0 ]]
		then
			printf "${GREEN}OK${NORMAL}\n"
			rm $image
		else
			printf "${RED}FAIL${NORMAL}\n"
		fi
		sleep 1 # In case processing took less than a second and the file is overwritten
	fi
done

# Done
printf "\n${BLUE}DONE${NORMAL}\n"
