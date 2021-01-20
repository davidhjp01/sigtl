# This adapted from part of https://github.com/RWTH-HPC/CMake-codecov.

set(CXX_COVERAGE_COMPILE_FLAGS
    -g -O0 --coverage -fprofile-arcs -ftest-coverage
    CACHE INTERNAL ""
)
set(CXX_COVERAGE_LINK_FLAGS
    --coverage
    CACHE INTERNAL ""
)

# Helper function to get the relative path of the source file destination path.
# This path is needed by FindGcov and FindLcov cmake files to locate the
# captured data.
function(codecov_path_of_source FILE RETURN_VAR)
  string(REGEX MATCH "TARGET_OBJECTS:([^ >]+)" _source ${FILE})

  # If expression was found, SOURCEFILE is a generator-expression for an object
  # library. Currently we found no way to call this function automatic for the
  # referenced target, so it must be called in the directoryso of the object
  # library definition.
  if(NOT "${_source}" STREQUAL "")
    set(${RETURN_VAR}
        ""
        PARENT_SCOPE
    )
    return()
  endif()

  string(REPLACE "${CMAKE_CURRENT_BINARY_DIR}/" "" FILE "${FILE}")
  if(IS_ABSOLUTE ${FILE})
    file(RELATIVE_PATH FILE ${CMAKE_CURRENT_SOURCE_DIR} ${FILE})
  endif()

  # get the right path for file
  string(REPLACE ".." "__" PATH "${FILE}")

  set(${RETURN_VAR}
      "${PATH}"
      PARENT_SCOPE
  )
endfunction()

# Add coverage flags for the given target.
function(add_coverage_flags target)
  if(ENABLE_COVERAGE)
    message(DEBUG "Enabling coverage for target: ${target}")
    # Add required flags (GCC & LLVM/Clang)
    target_compile_options(${target} PRIVATE ${CXX_COVERAGE_COMPILE_FLAGS})
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.13)
      target_link_options(${target} PRIVATE ${CXX_COVERAGE_LINK_FLAGS})
    else()
      target_link_libraries(${target} PRIVATE ${CXX_COVERAGE_LINK_FLAGS})
    endif()

    get_target_property(tsources ${target} SOURCES)
    set(target_compiler "")
    set(additional_files "")
    foreach(source_file ${tsources})
      list(APPEND additional_files "${source_file}.gcno")
      list(APPEND additional_files "${source_file}.gcda")
    endforeach()

    # Add gcov files generated by compiler to clean target.
    set(clean_files "")
    foreach(file ${additional_files})
      codecov_path_of_source(${file} file)
      list(APPEND clean_files
           "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target}.dir/${file}"
      )
    endforeach()
    set_target_properties(
      ${target} PROPERTIES ADDITIONAL_CLEAN_FILES "${clean_files}"
                           ADDITIONAL_MAKE_CLEAN_FILES "${clean_files}"
    )

    message(
      DEBUG
      "Adding following files to target (${target}) for cleaning:\n\t\t ---${clean_files}"
    )

  endif()
endfunction()

# Add coverage support for the given target and register target for coverage
# evaluation. If coverage is disabled or not supported, this function will
# simply do nothing.
function(add_coverage target)
  if(ENABLE_COVERAGE)
    message(STATUS "Adding coverage flags for target: ${target}")
    add_coverage_flags(${target})
  endif()
endfunction()

# Add global target to gather coverage information after all targets have been
# added. Other evaluation functions could be added here, after checks for the
# specific module have been passed.
function(coverage_evaluate)
  # add lcov evaluation
  if(LCOV_FOUND AND ENABLE_COVERAGE)
    lcov_capture_initial()
    lcov_capture()
  endif()
endfunction()
