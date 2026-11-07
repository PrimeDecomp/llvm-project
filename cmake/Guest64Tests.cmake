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
           ${WIBO_GUEST64_TEST_DIR}/guest64.dll ${WIBO_GUEST64_TEST_DIR}/compat32.exe
    COMMAND ${Python3_EXECUTABLE} ${WIBO_GUEST64_TEST_SOURCE}/build.py
            --clang ${WIBO_TEST_CLANG} --lld ${WIBO_TEST_LLD} --output ${WIBO_GUEST64_TEST_DIR}
    DEPENDS ${WIBO_GUEST64_TEST_SOURCE}/build.py ${WIBO_GUEST64_TEST_SOURCE}/basic.c ${WIBO_GUEST64_TEST_SOURCE}/compat32.c
            ${WIBO_GUEST64_TEST_SOURCE}/dll.c ${WIBO_GUEST64_TEST_SOURCE}/imports.c ${WIBO_GUEST64_TEST_SOURCE}/tls.c ${WIBO_GUEST64_TEST_SOURCE}/thread.c
            ${WIBO_GUEST64_TEST_SOURCE}/dll.def ${WIBO_GUEST64_TEST_SOURCE}/kernel32.def
    VERBATIM)
add_custom_target(wibo_test_fixtures ALL
    DEPENDS ${WIBO_GUEST64_TEST_DIR}/basic.exe ${WIBO_GUEST64_TEST_DIR}/imports.exe ${WIBO_GUEST64_TEST_DIR}/tls.exe ${WIBO_GUEST64_TEST_DIR}/thread.exe
            ${WIBO_GUEST64_TEST_DIR}/guest64.dll ${WIBO_GUEST64_TEST_DIR}/compat32.exe)
foreach(fixture basic imports tls thread)
    add_test(NAME wibo.guest64.${fixture}
             COMMAND $<TARGET_FILE:wibo> ${WIBO_GUEST64_TEST_DIR}/${fixture}.exe)
endforeach()
add_test(NAME wibo.guest64.reject32 COMMAND $<TARGET_FILE:wibo> ${WIBO_GUEST64_TEST_DIR}/compat32.exe)
set_tests_properties(wibo.guest64.reject32 PROPERTIES WILL_FAIL TRUE)
