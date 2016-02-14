#!/bin/bash -
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin" # needed for Cygwin
##############################################################################
# installer (c) 2015 Cardiff University, licensed under the EUPL V.1.1.
# written by Andreas Buerki
version="0.6"
####
# initialise some variables
export DESTINATION2="/" # for cygwin-only files
export cygwin_only="NGP.ico"
export linux_only="NGP.png"
export osx_only="NGP.app"
extended="-r"
# ascertain source directory
export sourcedir="$(dirname "$0")"
if [ "$(grep '^\.' <<<"$sourcedir")" ]; then
	sourcedir="$(pwd)/bin"
fi
# check it's in its proper directory
if [ "$(grep "$title" <<<"$sourcedir")" ]; then
	:
else
	echo "This installer script appears to have been moved out of its original directory. Please move it back into the $title directory and run it again." >&2
	sleep 2
	exit 1
fi
# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
elif [ "$(grep 'Darwin' <<< $platform)" ]; then
	extended="-E"
	DARWIN=true
else
	LINUX=true
fi
# run installer
if [ "$DARWIN" ]; then
	perl Makefile.PL
	make
	sudo make install
	make clean
else
	perl Makefile.PL
	make
	make test
	make install
	make clean
fi
if [ "$CYGWIN" ]; then
	cp "$sourcedir/$cygwin_only" "$DESTINATION2"
elif [ "$DARWIN" ]; then
	:
else
	mkdir $HOME/.icons 2>/dev/null
	cp "$sourcedir/$linux_only" $HOME/.icons
fi
# create Windows shortcuts if under cygwin
if [ "$CYGWIN" ]; then
	cd "$sourcedir" 2>/dev/null
	mkshortcut -n NGP -i /NGP.ico -w "$HOME" -a "-i /NGP.ico /bin/bash -l /usr/local/bin/NGP.sh" /bin/mintty
	read -t 10 -p 'Create shortcut on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp ./NGP.lnk /cygdrive/c/Users/"$USERNAME"/Desktop/ || echo "Could not find desktop, shortcut created in $(pwd)."
	else
		echo "Created Windows shortcut in $(pwd)."
	fi
	cd - 2>/dev/null
	echo ""
	echo "Installation complete."
	echo "To start the NGP, double-click on the NGP shortcut."
	echo "Feel free to move it anywhere convenient."
# create launcher if under Linux
elif [ "$LINUX" ]; then
	echo "[Desktop Entry]
Version=0.4
Encoding=UTF-8
Type=Application
Name=NGP
Comment=
Categories=Application;
Exec=/usr/local/bin/NGP.sh
Icon=NGP
Terminal=true
StartupNotify=false" > $sourcedir/NGP.desktop
	chmod a+x $sourcedir/NGP.desktop
	read -t 10 -p 'Create launcher on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp $sourcedir/NGP.desktop $HOME/Desktop/
	else
		echo "Launcher placed in $sourcedir."
	fi
	echo ""
	echo "Installation complete."
	echo "To start NGP, double-click on the NGP launcher."
	echo "Feel free to move it anywhere convenient."
elif [ "$DARWIN" ]; then
	cp -r "$sourcedir/$osx_only" /Applications || sudo cp -r "$sourcedir/$osx_only" /Applications 
	cp -r "$sourcedir/$osx_only" "$(dirname "$sourcedir")"
	echo "The application NGP was placed in your Applications folder."
	read -t 10 -p 'Create icon on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp -r "$sourcedir/$osx_only" $HOME/Desktop
	fi
	echo "Installation complete."
	echo
	echo "To start the NGP, double-click on the NGP icon in your Applications folder $(if [ -e "$HOME/Desktop/$osx_only" ]; then echo "or on your desktop";fi)."
	echo "Feel free to move it anywhere convenient."
fi
sleep 10
echo "This window can now be closed."
#perl Makefile.PL PREFIX=~/MyNGP LIB=~/MyPerlLib  OR  perl Makefile.PL INSTALL_BASE=/mydir/perl
#make
#make test
#make install

# Add this line to your .bashrc, .bash_profile, or .cshrc files as the case may be.
#export PERL5LIB=~/MyPerlLib