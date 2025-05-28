# Install a macos mobileconfig from the command line

Have a mobileconfig you want to apply to a computer from the commandline for
easy automation? Look no further than this tool!

This uses the private ConfigurationProfile.framework APIs to install the given
mobileconfig for the current user.

Requires disabling SIP.

# Usage

```
make
./installprofile <path/to/file.mobileconfig>
```
