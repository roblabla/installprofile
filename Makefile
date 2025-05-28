default: installprofile

installprofile-unsigned:
	$(CC) installprofile.m -F/System/Library/PrivateFrameworks -framework ConfigurationProfiles -framework Foundation -o installprofile-unsigned

installprofile: installprofile-unsigned
	cp installprofile-unsigned installprofile.tmp
	codesign --sign - --entitlements installprofile.entitlements.xml installprofile.tmp
	mv installprofile.tmp installprofile
