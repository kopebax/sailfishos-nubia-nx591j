LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := nubia-audiotest
LOCAL_MODULE_TAGS := optional
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES := audiotest.cpp
LOCAL_SHARED_LIBRARIES := libhardware liblog libcutils
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := nubia-audiobridge
LOCAL_MODULE_TAGS := optional
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES := audiobridge.cpp
LOCAL_SHARED_LIBRARIES := libhardware liblog libcutils
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := nubia-audiorec
LOCAL_MODULE_TAGS := optional
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES := audiorec.cpp
LOCAL_SHARED_LIBRARIES := libhardware liblog libcutils
include $(BUILD_EXECUTABLE)
