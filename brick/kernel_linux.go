package main

import "syscall"

func needsLegacyAdvertising() bool {
	var uts syscall.Utsname
	return syscall.Uname(&uts) == nil && uts.Release[0] == '4' && uts.Release[1] == '.' && uts.Release[2] == '9'
}
