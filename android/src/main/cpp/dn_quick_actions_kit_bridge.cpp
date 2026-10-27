// Copyright 2026 the quick_actions_kit contributors.
// SPDX-License-Identifier: Apache-2.0
#include <jni.h>
#include <dlfcn.h>
#include <cstdint>
#include <cstring>
#include <string>

static JavaVM* vm = nullptr;
static jclass bridge = nullptr;
static jmethodID initialize_method = nullptr;
static jmethodID request_method = nullptr;
using Generation = uint64_t (*)();
using Dispatcher = void (*)(int64_t, int32_t, const char*);
static Generation generation_fn = nullptr;
static void* core_handle = nullptr; // Kept alive for the cached symbol lifetime.
// Main-thread-only slot. Never copy it into queued native work.
static int64_t dispatcher_slot = 0;
static uint64_t dispatcher_generation = 0;

class Env {
 public:
  JNIEnv* value = nullptr;
  bool attached = false;
  Env() {
    if (!vm) return;
    jint status = vm->GetEnv(reinterpret_cast<void**>(&value), JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
      attached = vm->AttachCurrentThread(&value, nullptr) == JNI_OK;
      if (!attached) value = nullptr;
    } else if (status != JNI_OK) value = nullptr;
  }
  ~Env() { if (attached) vm->DetachCurrentThread(); }
};

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* java_vm, void*) {
  vm = java_vm;
  Env env;
  if (!env.value) return JNI_ERR;
  jclass local = env.value->FindClass("dev/dnplugins/quick_actions_kit/DNQuickActionsKitBridge");
  if (!local) return JNI_ERR;
  bridge = static_cast<jclass>(env.value->NewGlobalRef(local));
  env.value->DeleteLocalRef(local);
  initialize_method = env.value->GetStaticMethodID(bridge, "initialize", "(Z)V");
  request_method = env.value->GetStaticMethodID(bridge, "request", "(J[B)V");
  if (!initialize_method || !request_method || env.value->ExceptionCheck()) return JNI_ERR;
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT int32_t DNQuickActionsKitInitialize(int64_t pointer, int32_t new_session) {
  Env env;
  if (!env.value || !bridge) return 1;
  generation_fn = reinterpret_cast<Generation>(dlsym(RTLD_DEFAULT, "DN_IsolateGen"));
  if (!generation_fn) {
    // JVM-loaded libraries can be RTLD_LOCAL on Android. Resolve the public
    // symbol from the already loaded core without loading a second runtime.
    if (!core_handle) core_handle = dlopen("libdartnative_android.so", RTLD_NOW | RTLD_NOLOAD);
    if (core_handle) generation_fn = reinterpret_cast<Generation>(dlsym(core_handle, "DN_IsolateGen"));
  }
  if (!generation_fn) return 2; // Never retain a callback without restart protection.
  dispatcher_generation = generation_fn();
  dispatcher_slot = pointer;
  env.value->CallStaticVoidMethod(bridge, initialize_method, static_cast<jboolean>(new_session != 0));
  if (env.value->ExceptionCheck()) { env.value->ExceptionClear(); dispatcher_slot = 0; return 3; }
  return 0;
}

extern "C" JNIEXPORT int32_t DNQuickActionsKitRequest(int64_t token, const char* payload) {
  Env env;
  if (!env.value || !bridge || !payload || !generation_fn || dispatcher_generation != generation_fn()) return 1;
  const size_t length = std::strlen(payload);
  if (length > 1024 * 1024) return 1;
  jbyteArray bytes = env.value->NewByteArray(static_cast<jsize>(length));
  if (!bytes) { env.value->ExceptionClear(); return 1; }
  env.value->SetByteArrayRegion(bytes, 0, static_cast<jsize>(length), reinterpret_cast<const jbyte*>(payload));
  if (!env.value->ExceptionCheck()) env.value->CallStaticVoidMethod(bridge, request_method, static_cast<jlong>(token), bytes);
  env.value->DeleteLocalRef(bytes);
  if (env.value->ExceptionCheck()) { env.value->ExceptionClear(); return 1; }
  return 0;
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_dnplugins_quick_1actions_1kit_DNQuickActionsKitBridge_generation(JNIEnv*, jclass) {
  return generation_fn ? static_cast<jlong>(generation_fn()) : -1;
}
extern "C" JNIEXPORT void JNICALL
Java_dev_dnplugins_quick_1actions_1kit_DNQuickActionsKitBridge_resetDispatcher(JNIEnv*, jclass) {
  dispatcher_slot = 0;
}
extern "C" JNIEXPORT jboolean JNICALL
Java_dev_dnplugins_quick_1actions_1kit_DNQuickActionsKitBridge_deliver(
    JNIEnv* env, jclass, jlong token, jint kind, jbyteArray payload) {
  if (!generation_fn || dispatcher_generation != generation_fn() || !dispatcher_slot || !payload) return JNI_FALSE;
  const jsize length = env->GetArrayLength(payload);
  std::string text(static_cast<size_t>(length), '\0');
  env->GetByteArrayRegion(payload, 0, length, reinterpret_cast<jbyte*>(text.data()));
  if (env->ExceptionCheck()) { env->ExceptionClear(); return JNI_FALSE; }
  // Kotlin calls only on the main Looper; generation is rechecked at every fire.
  reinterpret_cast<Dispatcher>(dispatcher_slot)(token, kind, text.c_str());
  return JNI_TRUE;
}
