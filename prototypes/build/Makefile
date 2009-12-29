# HumanApi prototypes Makefile
#
# This allows you to easily create the correct environments for your
# HumanApi prototypes

DEV_DIR := ../dev/*

all: ecg tempinfo speedometer fridgeaid

clean:
	rm -Rf $(DEV_DIR)

fridgeaid:
	# Creating new PhoneGap project in dev/fridgeaid
	sh build_phonegap.sh fridgeaid

ceg:
	# Creating new PhoneGap project in dev/ceg
	sh build_phonegap.sh ceg

speedometer:
	# Creating new PhoneGap project in dev/speedometer
	sh build_phonegap.sh speedometer

tempinfo:
	# Creating new PhoneGap project in dev/tempinfo
	sh build_phonegap.sh tempinfo