# HumanApi prototypes Makefile
#
# This allows you to easily create the correct environments for your
# HumanApi prototypes

GIT_ROOT := ../
SOURCE_DIR := ../src
DEV_DIR := ../dev

all: ecg tempinfo speedometer fridgeaid

clean:
	rm -Rf $(DEV_DIR)/fridgeaid

fridgeaid:
	mkdir -p $(DEV_DIR)/fridgeaid/iphone
	cp -R "$(SOURCE_DIR)/phonegap/iphone/PhoneGap-based Application/" $(DEV_DIR)/fridgeaid/iphone

	# Replace vars
	cd $(DEV_DIR)/fridgeaid/iphone; \
	find . -name "___PROJECTNAMEASIDENTIFIER___*" | sed 's/\(.*\)\(___PROJECTNAMEASIDENTIFIER___\)\(.*\)/mv & \1fridgeaid\3/' | sh; \
	find . -name "___PROJECTNAME___*" | sed 's/\(.*\)\(___PROJECTNAME___\)\(.*\)/mv & \1fridgeaid\3/' | sh;

	# Teplace contents
	sh replace.sh $(DEV_DIR)/fridgeaid/iphone ___PROJECTNAMEASIDENTIFIER___ fridgeaid
	sh replace.sh $(DEV_DIR)/fridgeaid/iphone ___PROJECTNAME___ fridgeaid

	# Move www contents
	rm -Rf "$(DEV_DIR)/fridgeaid/iphone/www/"
	cp -R "$(SOURCE_DIR)/fridgeaid/www/" $(DEV_DIR)/fridgeaid/iphone/www

	# Add phonegap specific icons
	cp $(SOURCE_DIR)/fridgeaid/icons/Default.png $(DEV_DIR)/fridgeaid/iphone
	cp $(SOURCE_DIR)/fridgeaid/icons/icon.png $(DEV_DIR)/fridgeaid/iphone
