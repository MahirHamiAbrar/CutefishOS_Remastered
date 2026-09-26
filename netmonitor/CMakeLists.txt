cmake_minimum_required(VERSION 3.16)
project(cutefish-netmonitor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GRPC REQUIRED IMPORTED_TARGET grpc++ protobuf)
find_program(PROTOC protoc REQUIRED)
find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin REQUIRED)

# OpenSnitch's UI protocol (proto/ui.proto, from opensnitch 1.6.9).
set(PROTO ${CMAKE_CURRENT_SOURCE_DIR}/proto/ui.proto)
set(GEN ${CMAKE_CURRENT_BINARY_DIR})
add_custom_command(
    OUTPUT ${GEN}/ui.pb.cc ${GEN}/ui.pb.h ${GEN}/ui.grpc.pb.cc ${GEN}/ui.grpc.pb.h
    COMMAND ${PROTOC} -I ${CMAKE_CURRENT_SOURCE_DIR}/proto
            --cpp_out=${GEN} --grpc_out=${GEN}
            --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN} ${PROTO}
    DEPENDS ${PROTO})

add_executable(cutefish-netmonitor
    src/main.cpp
    src/monitor.cpp
    src/uiservice.cpp
    ${GEN}/ui.pb.cc
    ${GEN}/ui.grpc.pb.cc
    qml.qrc)

target_include_directories(cutefish-netmonitor PRIVATE ${GEN})
target_link_libraries(cutefish-netmonitor PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus PkgConfig::GRPC)

install(TARGETS cutefish-netmonitor RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES data/cutefish-netmonitor.desktop DESTINATION /etc/xdg/autostart)
# Not under /etc/cutefish: that path is cutefish-core's version file.
install(FILES data/cutefish-firewall.nft DESTINATION ${CMAKE_INSTALL_SYSCONFDIR})
install(FILES data/cutefish-firewall.service DESTINATION /usr/lib/systemd/system)
install(DIRECTORY data/opensnitch-rules/ DESTINATION ${CMAKE_INSTALL_DATADIR}/cutefish-netmonitor/opensnitch-rules)
