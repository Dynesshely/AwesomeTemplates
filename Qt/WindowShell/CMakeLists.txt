cmake_minimum_required(VERSION 3.24)

project(WindowShell VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Quick QuickControls2)
qt_standard_project_setup()
# components/fluent、pages 都是含 .qml 的子目录：NEW 策略让 Qt 自动为它们生成 qmldir，
# 否则每次 configure 都会报 QTP0004 警告。
qt_policy(SET QTP0004 NEW)

# 新增 C++ 源文件不用改本文件：CONFIGURE_DEPENDS 让 ninja 在目录变化时自动重新 glob。
file(GLOB_RECURSE SHELL_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")
# 控件按目录自动收编：components/ 放原子控件，pages/ 放展示页。
# 必须是相对路径：qt_add_qml_module 要把它们映射进 qrc，绝对路径会被拒绝。
file(GLOB_RECURSE SHELL_QML CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    "Main.qml"
    "components/*.qml"
    "pages/*.qml")
# build/ 里会被 qmlcache 写出编译产物，永远不要把它们当成源文件收进来
# （否则每次构建清单都变，ninja 会陷进 "manifest still dirty" 死循环）。
list(FILTER SHELL_QML EXCLUDE REGEX "^build/")

qt_add_executable(WindowShell WIN32 ${SHELL_SOURCES})
# src/platform 也要进 include 路径：QML 类型注册文件是按"头文件所在目录"生成 include 的。
target_include_directories(WindowShell PRIVATE src src/platform)

qt_add_qml_module(WindowShell
    URI WindowShell
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES ${SHELL_QML}
)

# 字体与图片走独立资源：QML 里用相对路径引用（components/ 下是 ../assets/...），
# 与源码树保持一致，本地直接跑和进 qrc 后都能解析。
qt_add_resources(WindowShell "shell_assets"
    PREFIX "/qt/qml/WindowShell"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}"
    FILES
        assets/fonts/FluentSystemIcons-Resizable.ttf
        assets/fonts/FluentSystemIcons-Resizable.json
        assets/fonts/LICENSE-FluentSystemIcons.txt
        assets/logo/app-256.png
        assets/logo/app-64.png
        assets/logo/app.svg
)

target_link_libraries(WindowShell PRIVATE Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2)
