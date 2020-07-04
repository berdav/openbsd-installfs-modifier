# OpenBSD custom install.fs

Helper script and virtual machine to create `installXX.fs`.

## Usage
To generate an `installerXX.fs` you need the target version
of OpenBSD you want to install.

1. Fire up the instance and push the `create_install.fs.sh` script to it.
   You can use the provided Vagrantfile using
   ```bash
   $ vagrant up
   ```
   This machine is configured to push the script to `/usr/local/bin/` via
   `ansible`.  Access to it using `vagrant ssh`.

2. Go to the directory that contains the target `authorized_keys` for the machine.

3. Launch the script without parameters, using the provided machine you don't need
   to provide any password.

4. Unzip and burn the `installXX.fs` to an USB or use [VM Injector](https://github.com/berdav/vm_injector)
   to run it into the cloud.
