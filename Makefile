default: installprofile

installprofile-unsigned: installprofile.m
	$(CC) installprofile.m -F/System/Library/PrivateFrameworks -framework ConfigurationProfiles -framework Foundation -o installprofile-unsigned

installprofile: installprofile-unsigned installprofile.entitlements.xml
	cp installprofile-unsigned installprofile.tmp
	codesign --sign - --entitlements installprofile.entitlements.xml installprofile.tmp
	mv installprofile.tmp installprofile
