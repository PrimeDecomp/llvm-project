find_program(WIBO_TEST_CLANG clang)
find_program(WIBO_TEST_LLD ld.lld)
if(NOT WIBO_TEST_CLANG OR NOT WIBO_TEST_LLD)
    message(WARNING "Clang and LLD are required for Win64 fixtures")
    return()
endif()
include(CTest)
set(WIBO_GUEST64_TEST_DIR ${CMAKE_CURRENT_BINARY_DIR}/test/guest64)
set(WIBO_GUEST64_TEST_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/test/guest64)
add_custom_command(
    OUTPUT ${WIBO_GUEST64_TEST_DIR}/basic.exe ${WIBO_GUEST64_TEST_DIR}/imports.exe ${WIBO_GUEST64_TEST_DIR}/tls.exe ${WIBO_GUEST64_TEST_DIR}/thread.exe
           ${WIBO_GUEST64_TEST_DIR}/guest64.dll ${WIBO_GUEST64_TEST_DIR}/compat32.exe ${WIBO_GUEST64_TEST_DIR}/wine_debug.exe ${WIBO_GUEST64_TEST_DIR}/memory.exe ${WIBO_GUEST64_TEST_DIR}/memory_wine.exe ${WIBO_GUEST64_TEST_DIR}/search_path.exe ${WIBO_GUEST64_TEST_DIR}/search_path_wine.exe ${WIBO_GUEST64_TEST_DIR}/redirect.exe
    COMMAND ${Python3_EXECUTABLE} ${WIBO_GUEST64_TEST_SOURCE}/build.py
            --clang ${WIBO_TEST_CLANG} --lld ${WIBO_TEST_LLD} --output ${WIBO_GUEST64_TEST_DIR}
    DEPENDS ${WIBO_GUEST64_TEST_SOURCE}/build.py ${WIBO_GUEST64_TEST_SOURCE}/basic.c ${WIBO_GUEST64_TEST_SOURCE}/compat32.c
            ${WIBO_GUEST64_TEST_SOURCE}/dll.c ${WIBO_GUEST64_TEST_SOURCE}/imports.c ${WIBO_GUEST64_TEST_SOURCE}/tls.c ${WIBO_GUEST64_TEST_SOURCE}/thread.c
            ${WIBO_GUEST64_TEST_SOURCE}/dll.def ${WIBO_GUEST64_TEST_SOURCE}/kernel32.def
            ${WIBO_GUEST64_TEST_SOURCE}/search_path.c ${WIBO_GUEST64_TEST_SOURCE}/redirect.c ${WIBO_GUEST64_TEST_SOURCE}/memory.c ${WIBO_GUEST64_TEST_SOURCE}/wine_debug.c ${WIBO_GUEST64_TEST_SOURCE}/ntdll.def
    VERBATIM)
add_custom_target(wibo_test_fixtures ALL
    DEPENDS ${WIBO_GUEST64_TEST_DIR}/basic.exe ${WIBO_GUEST64_TEST_DIR}/imports.exe ${WIBO_GUEST64_TEST_DIR}/tls.exe ${WIBO_GUEST64_TEST_DIR}/thread.exe
            ${WIBO_GUEST64_TEST_DIR}/guest64.dll ${WIBO_GUEST64_TEST_DIR}/compat32.exe ${WIBO_GUEST64_TEST_DIR}/wine_debug.exe ${WIBO_GUEST64_TEST_DIR}/memory.exe ${WIBO_GUEST64_TEST_DIR}/memory_wine.exe ${WIBO_GUEST64_TEST_DIR}/search_path.exe ${WIBO_GUEST64_TEST_DIR}/search_path_wine.exe ${WIBO_GUEST64_TEST_DIR}/redirect.exe)
foreach(fixture basic imports tls thread wine_debug memory search_path)
    add_test(NAME wibo.guest64.${fixture}
             COMMAND $<TARGET_FILE:wibo> ${WIBO_GUEST64_TEST_DIR}/${fixture}.exe)
endforeach()
add_test(NAME wibo.guest64.wine_debug_verbose
         COMMAND $<TARGET_FILE:wibo> -D ${WIBO_GUEST64_TEST_DIR}/wine_debug.exe)
add_test(NAME wibo.guest64.reject32 COMMAND $<TARGET_FILE:wibo> ${WIBO_GUEST64_TEST_DIR}/compat32.exe)
set_tests_properties(wibo.guest64.reject32 PROPERTIES WILL_FAIL TRUE)

add_test(NAME wibo.guest64.redirect
    COMMAND ${Python3_EXECUTABLE} ${WIBO_GUEST64_TEST_SOURCE}/redirect.py
            $<TARGET_FILE:wibo> ${WIBO_GUEST64_TEST_DIR}/redirect.exe)
