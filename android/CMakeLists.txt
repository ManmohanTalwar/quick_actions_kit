cmake_minimum_required(VERSION 3.22.1)
project("quick_actions_kit" C CXX)

# libquick_actions_kit.so: the bridge Dart opens by this name
# (lib/src/quick_actions_kit_bindings.dart) and QuickActionsKitPlugin.kt loads.
add_library(quick_actions_kit SHARED
    src/main/cpp/dn_quick_actions_kit_bridge.cpp
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_library(log-lib log)
find_library(dl-lib dl)

target_link_libraries(quick_actions_kit
    ${log-lib}
    ${dl-lib}
)

# 16 KB page alignment, required by Google Play on Android 15 and later.
target_link_options(quick_actions_kit PRIVATE "-Wl,-z,max-page-size=16384")
