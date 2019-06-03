include $(THEOS)/makefiles/common.mk

export TARGET = iphone:clang:12.1.2:11.0
export ARCHS = arm64 arm64e

TWEAK_NAME = SaveVideoDialog
SaveVideoDialog_FILES = Tweak.xm
SaveVideoDialog_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Camera"
