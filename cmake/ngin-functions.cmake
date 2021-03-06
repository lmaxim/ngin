include( CMakeParseArguments )

set( __ngin_toolsRoot ${__ngin_rootDir}/tools
     CACHE INTERNAL "__ngin_toolsRoot" )

# -----------------------------------------------------------------------------

# \todo Make it possible to specify the segment for the common data and each
#       map separately.
# \todo If SYMBOLS are left empty, use the MAPS filenames with extension stripped
#       (and underscore placement) as the symbol.
# OUTFILE:  Prefix for the output filenames
# MAPS:     List of TMX maps that should be imported
# SYMBOLS:  List of symbols corresponding to each map listed in MAPS
# DEPENDS:  Additional dependencies (e.g. tileset images/files)
function( ngin_addMapAssets target )
    cmake_parse_arguments(
        TOOLARGS
        ""                                          # Options
        "OUTFILE;SEGMENT_GRANULARITY;DATA_SEGMENT"  # One-value arguments
        "MAPS;SYMBOLS;DEPENDS;SEGMENTS"             # Multi-value arguments
        ${ARGN}
    )

    set( tiledMapImporter
        ${__ngin_toolsRoot}/tiled-map-importer/tiled-map-importer.py
    )

    set( extraArgs "" )
    if ( TOOLARGS_SEGMENT_GRANULARITY )
        list( APPEND extraArgs -r ${TOOLARGS_SEGMENT_GRANULARITY} )
    endif()
    if ( TOOLARGS_SEGMENTS )
        string( REPLACE ";" "," segmentsComma "${TOOLARGS_SEGMENTS}" )
        list( APPEND extraArgs -g ${segmentsComma} )
    endif()
    if ( TOOLARGS_DATA_SEGMENT )
        list( APPEND extraArgs -d ${TOOLARGS_DATA_SEGMENT} )
    endif()

    # \todo Check that TOOLARGS_OUTFILE is not empty, and that length of
    #       TOOLARGS_MAPS is equal to length of TOOLARGS_SYMBOLS.
    # \todo Make sure that all dependencies and missing outputs cause a
    #       recompile properly.
    add_custom_command(
        OUTPUT
            ${TOOLARGS_OUTFILE}.s
            ${TOOLARGS_OUTFILE}.inc
            ${TOOLARGS_OUTFILE}.chr
        COMMAND
            ${__ngin_python} ${tiledMapImporter}
            -i ${TOOLARGS_MAPS}
            -s ${TOOLARGS_SYMBOLS}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${TOOLARGS_OUTFILE}
            ${extraArgs}
        DEPENDS
            ${tiledMapImporter}
            # \todo May need to expand to full path to avoid UB?
            ${TOOLARGS_MAPS}
            ${TOOLARGS_DEPENDS}
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT
            "tiled-map-importer.py: Importing ${TOOLARGS_MAPS}"
        VERBATIM
    )

    add_library( ${target}
        ${TOOLARGS_OUTFILE}.s
    )

    target_link_libraries( ${target} ngin )

    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    file( RELATIVE_PATH currentSourceDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR} )

    set_target_properties( ${target}
        PROPERTIES
            COMPILE_FLAGS "\
${__ngin_compileFlags} \
--asm-include-dir ${currentBinaryDirRelative} \
--asm-include-dir ${currentSourceDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
    )
endfunction()

# -----------------------------------------------------------------------------

function( ngin_spriteAssetLibrary target )
    cmake_parse_arguments(
        TOOLARGS
        "8X16"                                      # Options
        "OUTFILE;XGRID;YGRID;SEGMENT_GRANULARITY"   # One-value arguments
        "SEGMENTS"                                  # Multi-value arguments
        ${ARGN}
    )

    # Take note of the variables. They will be applied in
    # ngin_endSpriteAssetLibrary.

    set( __ngin_spriteAsset_extraArgs "" )
    if ( TOOLARGS_8X16 )
        list( APPEND __ngin_spriteAsset_extraArgs --8x16 )
    endif()
    if ( TOOLARGS_XGRID )
        list( APPEND __ngin_spriteAsset_extraArgs -x ${TOOLARGS_XGRID} )
    endif()
    if ( TOOLARGS_YGRID )
        list( APPEND __ngin_spriteAsset_extraArgs -y ${TOOLARGS_YGRID} )
    endif()
    if ( TOOLARGS_SEGMENT_GRANULARITY )
        list( APPEND __ngin_spriteAsset_extraArgs -r ${TOOLARGS_SEGMENT_GRANULARITY} )
    endif()
    if ( TOOLARGS_SEGMENTS )
        string( REPLACE ";" "," segmentsComma "${TOOLARGS_SEGMENTS}" )
        list( APPEND __ngin_spriteAsset_extraArgs -g ${segmentsComma} )
    endif()

    # Export to parent scope.
    set( __ngin_spriteAsset_extraArgs ${__ngin_spriteAsset_extraArgs} PARENT_SCOPE )
    set( __ngin_spriteAsset_target ${target} PARENT_SCOPE )
    set( __ngin_spriteAsset_outfile ${TOOLARGS_OUTFILE} PARENT_SCOPE )
    set( __ngin_spriteAsset_images  "" PARENT_SCOPE )
    set( __ngin_spriteAsset_depends "" PARENT_SCOPE )
    set( __ngin_spriteAsset_args    "" PARENT_SCOPE )
endfunction()

function( ngin_spriteAsset )
    cmake_parse_arguments(
        TOOLARGS
        "HFLIP;VFLIP;HVFLIP"            # Options
        "DELAY;PALETTE_ADD"             # One-value arguments
        "IMAGE;SYMBOL;DEPENDS"          # Multi-value arguments
        ${ARGN}
    )

    # If empty, figure out a symbol based on the file name.
    if ( "${TOOLARGS_SYMBOL}" STREQUAL "" )
        # Remove the extension.
        get_filename_component( TOOLARGS_SYMBOL ${TOOLARGS_IMAGE} NAME_WE )

        # Turn it into a C-compatible identifier.
        string( MAKE_C_IDENTIFIER ${TOOLARGS_SYMBOL} TOOLARGS_SYMBOL )
    endif()

    list( APPEND __ngin_spriteAsset_images ${TOOLARGS_IMAGE} )
    list( APPEND __ngin_spriteAsset_depends ${TOOLARGS_DEPENDS} )

    if ( TOOLARGS_HFLIP )
        list( APPEND __ngin_spriteAsset_args "--hflip" )
    endif()

    if ( TOOLARGS_VFLIP )
        list( APPEND __ngin_spriteAsset_args "--vflip" )
    endif()

    if ( TOOLARGS_HVFLIP )
        list( APPEND __ngin_spriteAsset_args "--hvflip" )
    endif()

    if ( TOOLARGS_DELAY )
        list( APPEND __ngin_spriteAsset_args "--delay" ${TOOLARGS_DELAY} )
    endif()

    if ( TOOLARGS_PALETTE_ADD )
        list( APPEND __ngin_spriteAsset_args "--paletteadd" ${TOOLARGS_PALETTE_ADD} )
    endif()

    list( APPEND __ngin_spriteAsset_args
        -s ${TOOLARGS_SYMBOL}
        -i ${TOOLARGS_IMAGE}
    )

    # Export to parent scope.
    set( __ngin_spriteAsset_images ${__ngin_spriteAsset_images} PARENT_SCOPE )
    set( __ngin_spriteAsset_depends ${__ngin_spriteAsset_depends} PARENT_SCOPE )
    set( __ngin_spriteAsset_args ${__ngin_spriteAsset_args} PARENT_SCOPE )
endfunction()

function( ngin_spriteAssetEvent )
    # \todo Allow multiple callbacks to be specified?
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        "ON_FRAME;CALLBACK"             # One-value arguments
        ""                              # Multi-value arguments
        ${ARGN}
    )

    # \todo ON_FRAME shouldn't be allowed to be empty.

    list( APPEND __ngin_spriteAsset_args "--onframe" "${TOOLARGS_ON_FRAME},${TOOLARGS_CALLBACK}" )

    # Export to parent scope.
    set( __ngin_spriteAsset_args ${__ngin_spriteAsset_args} PARENT_SCOPE )
endfunction()

function( ngin_endSpriteAssetLibrary )
    set( spriteImporter
        ${__ngin_toolsRoot}/sprite-importer/sprite-importer.py
    )

    add_custom_command(
        OUTPUT
            ${__ngin_spriteAsset_outfile}.s
            ${__ngin_spriteAsset_outfile}.inc
            ${__ngin_spriteAsset_outfile}.chr
        COMMAND
            ${__ngin_python} ${spriteImporter}
            ${__ngin_spriteAsset_args}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${__ngin_spriteAsset_outfile}
            ${__ngin_spriteAsset_extraArgs}
        DEPENDS
            ${spriteImporter}
            # \todo May need to expand to full path to avoid UB?
            ${__ngin_spriteAsset_images}
            ${__ngin_spriteAsset_depends}
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT
            "sprite-importer.py: Importing ${__ngin_spriteAsset_images}"
        VERBATIM
    )

    add_library( ${__ngin_spriteAsset_target}
        ${__ngin_spriteAsset_outfile}.s
    )

    target_link_libraries( ${__ngin_spriteAsset_target} ngin )

    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    set_target_properties( ${__ngin_spriteAsset_target}
        PROPERTIES
            COMPILE_FLAGS "\
${__ngin_compileFlags} \
--asm-include-dir ${currentBinaryDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
    )
endfunction()

# -----------------------------------------------------------------------------

function( ngin_paletteAssetLibrary target )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        "OUTFILE"                       # One-value arguments
        ""                              # Multi-value arguments
        ${ARGN}
    )

    # Export to parent scope.
    set( __ngin_paletteAsset_target ${target} PARENT_SCOPE )
    set( __ngin_paletteAsset_outfile ${TOOLARGS_OUTFILE} PARENT_SCOPE )
    set( __ngin_paletteAsset_images  "" PARENT_SCOPE )
    set( __ngin_paletteAsset_depends "" PARENT_SCOPE )
    set( __ngin_paletteAsset_args    "" PARENT_SCOPE )
endfunction()

function( ngin_paletteAsset )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        ""                              # One-value arguments
        "IMAGE;SYMBOL;DEPENDS"          # Multi-value arguments
        ${ARGN}
    )

    # If empty, figure out a symbol based on the file name.
    if ( "${TOOLARGS_SYMBOL}" STREQUAL "" )
        # Remove the extension.
        get_filename_component( TOOLARGS_SYMBOL ${TOOLARGS_IMAGE} NAME_WE )

        # Turn it into a C-compatible identifier.
        string( MAKE_C_IDENTIFIER ${TOOLARGS_SYMBOL} TOOLARGS_SYMBOL )
    endif()

    list( APPEND __ngin_paletteAsset_images ${TOOLARGS_IMAGE} )
    list( APPEND __ngin_paletteAsset_depends ${TOOLARGS_DEPENDS} )

    list( APPEND __ngin_paletteAsset_args
        -s ${TOOLARGS_SYMBOL}
        -i ${TOOLARGS_IMAGE}
    )

    # Export to parent scope.
    set( __ngin_paletteAsset_images ${__ngin_paletteAsset_images} PARENT_SCOPE )
    set( __ngin_paletteAsset_depends ${__ngin_paletteAsset_depends} PARENT_SCOPE )
    set( __ngin_paletteAsset_args ${__ngin_paletteAsset_args} PARENT_SCOPE )
endfunction()

function( ngin_endPaletteAssetLibrary )
    set( paletteImporter
        ${__ngin_toolsRoot}/palette-importer/palette-importer.py
    )

    add_custom_command(
        OUTPUT
            ${__ngin_paletteAsset_outfile}.s
            ${__ngin_paletteAsset_outfile}.inc
        COMMAND
            ${__ngin_python} ${paletteImporter}
            ${__ngin_paletteAsset_args}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${__ngin_paletteAsset_outfile}
        DEPENDS
            ${paletteImporter}
            # \todo May need to expand to full path to avoid UB?
            ${__ngin_paletteAsset_images}
            ${__ngin_paletteAsset_depends}
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT
            "palette-importer.py: Importing ${__ngin_paletteAsset_images}"
        VERBATIM
    )

    add_library( ${__ngin_paletteAsset_target}
        ${__ngin_paletteAsset_outfile}.s
    )

    target_link_libraries( ${__ngin_paletteAsset_target} ngin )

    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    set_target_properties( ${__ngin_paletteAsset_target}
        PROPERTIES
            COMPILE_FLAGS "\
${__ngin_compileFlags} \
--asm-include-dir ${currentBinaryDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
    )
endfunction()

# -----------------------------------------------------------------------------

function( ngin_museSoundAssetLibrary target )
    # \todo Options for segments (song segments, DPCM segment, etc)
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        "OUTFILE"                       # One-value arguments
        ""                              # Multi-value arguments
        ${ARGN}
    )

    # Export to parent scope.
    set( __ngin_museSoundAsset_target ${target} PARENT_SCOPE )
    set( __ngin_museSoundAsset_outfile ${TOOLARGS_OUTFILE} PARENT_SCOPE )
    set( __ngin_museSoundAsset_songs        "" PARENT_SCOPE )
    set( __ngin_museSoundAsset_soundEffects "" PARENT_SCOPE )
    set( __ngin_museSoundAsset_symbols      "" PARENT_SCOPE )
    set( __ngin_museSoundAsset_depends      "" PARENT_SCOPE )
endfunction()

function( ngin_museSongAsset )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        ""                              # One-value arguments
        "SONG;SYMBOL;DEPENDS"           # Multi-value arguments
        ${ARGN}
    )

    # If empty, figure out a symbol based on the file name.
    if ( "${TOOLARGS_SYMBOL}" STREQUAL "" )
        # Remove the extension.
        get_filename_component( TOOLARGS_SYMBOL ${TOOLARGS_SONG} NAME_WE )

        # Turn it into a C-compatible identifier.
        string( MAKE_C_IDENTIFIER ${TOOLARGS_SYMBOL} TOOLARGS_SYMBOL )
    endif()

    list( APPEND __ngin_museSoundAsset_songs   ${TOOLARGS_SONG} )
    list( APPEND __ngin_museSoundAsset_symbols ${TOOLARGS_SYMBOL} )
    list( APPEND __ngin_museSoundAsset_depends ${TOOLARGS_DEPENDS} )

    # Export to parent scope.
    set( __ngin_museSoundAsset_songs   ${__ngin_museSoundAsset_songs}   PARENT_SCOPE )
    set( __ngin_museSoundAsset_symbols ${__ngin_museSoundAsset_symbols} PARENT_SCOPE )
    set( __ngin_museSoundAsset_depends ${__ngin_museSoundAsset_depends} PARENT_SCOPE )
endfunction()

function( ngin_museSoundEffectAsset )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        ""                              # One-value arguments
        "EFFECT;SYMBOL;DEPENDS"         # Multi-value arguments
        ${ARGN}
    )

    # If empty, figure out a symbol based on the file name.
    if ( "${TOOLARGS_SYMBOL}" STREQUAL "" )
        # Remove the extension.
        get_filename_component( TOOLARGS_SYMBOL ${TOOLARGS_EFFECT} NAME_WE )

        # Turn it into a C-compatible identifier.
        string( MAKE_C_IDENTIFIER ${TOOLARGS_SYMBOL} TOOLARGS_SYMBOL )
    endif()

    list( APPEND __ngin_museSoundAsset_soundEffects ${TOOLARGS_EFFECT} )
    list( APPEND __ngin_museSoundAsset_symbols      ${TOOLARGS_SYMBOL} )
    list( APPEND __ngin_museSoundAsset_depends      ${TOOLARGS_DEPENDS} )

    # Export to parent scope.
    set( __ngin_museSoundAsset_soundEffects ${__ngin_museSoundAsset_soundEffects} PARENT_SCOPE )
    set( __ngin_museSoundAsset_symbols      ${__ngin_museSoundAsset_symbols} PARENT_SCOPE )
    set( __ngin_museSoundAsset_depends      ${__ngin_museSoundAsset_depends} PARENT_SCOPE )
endfunction()

function( ngin_endMuseSoundAssetLibrary )
    set( musetrackerImporter
        ${__ngin_toolsRoot}/musetracker-importer/musetracker-importer.py
    )

    set( allInputs
        ${__ngin_museSoundAsset_songs}
        ${__ngin_museSoundAsset_soundEffects}
    )

    add_custom_command(
        OUTPUT
            ${__ngin_museSoundAsset_outfile}.s
            ${__ngin_museSoundAsset_outfile}.inc
        COMMAND
            ${__ngin_python} ${musetrackerImporter}
            -m ${__ngin_musetracker}
            -i ${__ngin_museSoundAsset_songs}
            -e ${__ngin_museSoundAsset_soundEffects}
            -s ${__ngin_museSoundAsset_symbols}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${__ngin_museSoundAsset_outfile}
        DEPENDS
            ${musetrackerImporter}
            # \todo May need to expand to full path to avoid UB?
            ${__ngin_museSoundAsset_songs}
            ${__ngin_museSoundAsset_soundEffects}
            ${__ngin_museSoundAsset_depends}
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT
            "musetracker-importer.py: Importing ${allInputs}"
        VERBATIM
    )

    add_library( ${__ngin_museSoundAsset_target}
        ${__ngin_museSoundAsset_outfile}.s
    )

    target_link_libraries( ${__ngin_museSoundAsset_target} ngin )

    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    # \todo Factor out to a function.
    set_target_properties( ${__ngin_museSoundAsset_target}
        PROPERTIES
            COMPILE_FLAGS "\
${__ngin_compileFlags} \
--asm-include-dir ${currentBinaryDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
    )
endfunction()

# -----------------------------------------------------------------------------

function( __ngin_linkerConfiguration )
    cmake_parse_arguments(
        TOOLARGS
        ""                                          # Options
        "OUTFILE;MAPPER;PRG_SIZE;CHR_SIZE"          # One-value arguments
        ""                                          # Multi-value arguments
        ${ARGN}
    )

    set( linkerConfigurer
        ${__ngin_toolsRoot}/linker-configurer/linker-configurer.py
    )

    add_custom_command(
        OUTPUT
            ${TOOLARGS_OUTFILE}
        COMMAND
            ${__ngin_python} ${linkerConfigurer}
            -m ${TOOLARGS_MAPPER}
            -p ${TOOLARGS_PRG_SIZE}
            -c ${TOOLARGS_CHR_SIZE}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${TOOLARGS_OUTFILE}
        DEPENDS
            ${linkerConfigurer}
        COMMENT
            "linker-configurer.py: Generating config for ${TOOLARGS_MAPPER}"
        VERBATIM
    )
endfunction()

# -----------------------------------------------------------------------------

function( ngin_mspAssetLibrary target )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        "OUTFILE"                       # One-value arguments
        ""                              # Multi-value arguments
        ${ARGN}
    )

    # Take note of the variables. They will be applied in
    # ngin_endMspAssetLibrary. Currently there are no available settings.

    set( __ngin_mspAsset_extraArgs "" )

    # Export to parent scope.
    set( __ngin_mspAsset_extraArgs ${__ngin_mspAsset_extraArgs} PARENT_SCOPE )
    set( __ngin_mspAsset_target ${target} PARENT_SCOPE )
    set( __ngin_mspAsset_outfile ${TOOLARGS_OUTFILE} PARENT_SCOPE )
    set( __ngin_mspAsset_msps    "" PARENT_SCOPE )
    set( __ngin_mspAsset_depends "" PARENT_SCOPE )
    set( __ngin_mspAsset_args    "" PARENT_SCOPE )
endfunction()

function( ngin_mspAsset )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        ""                              # One-value arguments
        "MSP;SYMBOL_PREFIX;DEPENDS"     # Multi-value arguments
        ${ARGN}
    )

    # If empty, figure out a symbol based on the file name.
    if ( "${TOOLARGS_SYMBOL_PREFIX}" STREQUAL "" )
        # Remove the extension.
        get_filename_component( TOOLARGS_SYMBOL_PREFIX ${TOOLARGS_MSP} NAME_WE )

        # Turn it into a C-compatible identifier.
        string( MAKE_C_IDENTIFIER ${TOOLARGS_SYMBOL_PREFIX} TOOLARGS_SYMBOL_PREFIX )
    endif()

    list( APPEND __ngin_mspAsset_msps ${TOOLARGS_MSP} )
    list( APPEND __ngin_mspAsset_depends ${TOOLARGS_DEPENDS} )

    list( APPEND __ngin_mspAsset_args
        -s ${TOOLARGS_SYMBOL_PREFIX}
        -i ${TOOLARGS_MSP}
    )

    # Export to parent scope.
    set( __ngin_mspAsset_msps ${__ngin_mspAsset_msps} PARENT_SCOPE )
    set( __ngin_mspAsset_depends ${__ngin_mspAsset_depends} PARENT_SCOPE )
    set( __ngin_mspAsset_args ${__ngin_mspAsset_args} PARENT_SCOPE )
endfunction()

function( ngin_endMspAssetLibrary )
    set( mspImporter
        ${__ngin_toolsRoot}/msp-importer/msp-importer.py
    )

    add_custom_command(
        OUTPUT
            ${__ngin_mspAsset_outfile}.s
            ${__ngin_mspAsset_outfile}.inc
        COMMAND
            ${__ngin_python} ${mspImporter}
            ${__ngin_mspAsset_args}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${__ngin_mspAsset_outfile}
            ${__ngin_mspAsset_extraArgs}
        DEPENDS
            ${mspImporter}
            # \todo May need to expand to full path to avoid UB?
            ${__ngin_mspAsset_msps}
            ${__ngin_mspAsset_depends}
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT
            "msp-importer.py: Importing ${__ngin_mspAsset_msps}"
        VERBATIM
    )

    add_library( ${__ngin_mspAsset_target}
        ${__ngin_mspAsset_outfile}.s
    )

    target_link_libraries( ${__ngin_mspAsset_target} ngin )

    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    set_target_properties( ${__ngin_mspAsset_target}
        PROPERTIES
            COMPILE_FLAGS "\
${__ngin_compileFlags} \
--asm-include-dir ${currentBinaryDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
    )
endfunction()

# -----------------------------------------------------------------------------

function( ngin_addExecutable name )
    cmake_parse_arguments(
        TOOLARGS
        ""                              # Options
        "MAPPER;PRG_SIZE;CHR_SIZE"      # One-value arguments
        ""                              # Multi-value arguments
        ${ARGN}
    )

    # Default settings.
    if ( NOT TOOLARGS_MAPPER )
        set( TOOLARGS_MAPPER "nrom" )
    endif()

    if ( NOT TOOLARGS_PRG_SIZE )
        set( TOOLARGS_PRG_SIZE 16 )
    endif()

    if ( NOT TOOLARGS_CHR_SIZE )
        set( TOOLARGS_CHR_SIZE 8 )
    endif()

    # Turn mapper name into an uppercase C-compatible string.
    string( MAKE_C_IDENTIFIER ${TOOLARGS_MAPPER} mapperIdUpper )
    string( TOUPPER ${mapperIdUpper} mapperIdUpper )

    # Make into a define for compilation (e.g. NGIN_MAPPER_NROM).
    set( mapperDefine "NGIN_MAPPER_${mapperIdUpper}" )

    # Generate linker configuration for the current executable. Need to
    # generate per-executable because parameters like PRG/CHR size might
    # change.
    set( linkerConfigFilename "${name}.linker.cfg" )
    __ngin_linkerConfiguration(
        OUTFILE         ${linkerConfigFilename}
        MAPPER          ${TOOLARGS_MAPPER}
        PRG_SIZE        ${TOOLARGS_PRG_SIZE}
        CHR_SIZE        ${TOOLARGS_CHR_SIZE}
    )

    set( linkerConfig ${CMAKE_CURRENT_BINARY_DIR}/${linkerConfigFilename} )
    set( linkerConfigDummy ${__ngin_sourceDir}/linker-config-dummy.s )

    set_source_files_properties( ${linkerConfigDummy}
        PROPERTIES
            OBJECT_DEPENDS ${linkerConfig}
    )

    add_executable( ${name}
        ${linkerConfigDummy}
        ${__ngin_sourceDir}/ines-header.s
        ${TOOLARGS_UNPARSED_ARGUMENTS}
    )

    # Add the binary directory as include and binary include directory
    # so that results generated by asset processing tools are found.
    # Specifying absolute path for --asm-include-dir and
    # --bin-include-dir causes absolute path references to show up in
    # the dependency file generated by ca65, which for some reason
    # confuses Ninja's dependency resolution, so we convert to a
    # relative path.
    file( RELATIVE_PATH currentBinaryDirRelative ${CMAKE_BINARY_DIR}
        ${CMAKE_CURRENT_BINARY_DIR} )

    set_target_properties( ${name}
        PROPERTIES
            OUTPUT_NAME ${name}.nes
            COMPILE_FLAGS "${__ngin_compileFlags} \
-D ${mapperDefine} --asm-define ${mapperDefine} \
--asm-include-dir ${currentBinaryDirRelative} \
--bin-include-dir ${currentBinaryDirRelative}"
            # \note --force-import is needed to bring in object files from the
            #       static library which would be otherwise stripped.
            LINK_FLAGS "-t none -C ${linkerConfig} \
--force-import __ngin_forceImport \
--force-import __ngin_initMapper_${mapperIdUpper} \
-Wl --dbgfile,${currentBinaryDirRelative}/${name}.nes.dbg \
-m ${currentBinaryDirRelative}/${name}-map.txt"
    )

    target_link_libraries( ${name}
        ngin
    )

    # Add a custom target to start an emulator.
    add_custom_target(
        "start-${name}"
        COMMAND
            ${__ngin_ndx} ${currentBinaryDirRelative}/${name}.nes
        DEPENDS ${name}
        # \note NDX v36 or later is required for this to work,
        #       older versions will not find the source files relative to the
        #       current working directory.
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Running ${name}"
        VERBATIM
    )
endfunction()
