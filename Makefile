# clipwire - iOS 26.1 (23B85) vm_map_clip race + vm_fault_wire_object_pages OOB
#
# Build on macOS/iPhone with clang (SDK) + ldid, mirroring darksword-kexploit.
#
#   make           -> build clipwire (arm64e)
#   make sign      -> ldid -S with entitlements.plist
#   make deploy    -> scp to device and run over ssh (requires jailbreak SSH)

CC      = clang
TARGET  = clipwire
SRCS    = src/main.m src/util.c src/slide.c src/trigger.c src/wire.c src/exploit.c src/krw.c
ARCH    = arm64e

SDKROOT := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)

CFLAGS  = -fobjc-arc -arch $(ARCH) -miphoneos-version-min=15.0 \
          -isysroot $(SDKROOT) -Wall -Wno-deprecated-declarations -O2
LDFLAGS = -framework IOSurface -framework Foundation

all: $(TARGET)

$(TARGET): $(SRCS) src/clipwire.h
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@

sign: $(TARGET)
	ldid -Sentitlements.plist $(TARGET)
	ldid -e $(TARGET) | head -40

deploy: sign
	scp $(TARGET) root@$(DEVICE_IP):/var/tmp/
	ssh root@$(DEVICE_IP) '/var/tmp/$(TARGET)'

clean:
	rm -f $(TARGET)
