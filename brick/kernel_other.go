//go:build !linux

package main

// Allows portable protocol tests; the service itself runs only on Brick/Linux.
func needsLegacyAdvertising() bool { return false }
