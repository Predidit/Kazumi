
# must define SHADER_COMP_HEADER SHADER_SRC

file(READ ${SHADER_SRC} comp_data)

# skip leading comment
string(FIND "${comp_data}" "#version" version_start)
string(SUBSTRING "${comp_data}" ${version_start} -1 comp_data)

# remove whitespace
string(REGEX REPLACE "\n +" "\n" comp_data "${comp_data}")

get_filename_component(SHADER_SRC_NAME_WE ${SHADER_SRC} NAME_WE)

# text to hex
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${SHADER_SRC_NAME_WE}.text2hex.txt "${comp_data}")
file(READ ${CMAKE_CURRENT_BINARY_DIR}/${SHADER_SRC_NAME_WE}.text2hex.txt comp_data_hex HEX)
string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," comp_data_hex ${comp_data_hex})
string(FIND "${comp_data_hex}" "," tail_comma REVERSE)
string(SUBSTRING "${comp_data_hex}" 0 ${tail_comma} comp_data_hex)

file(WRITE ${SHADER_COMP_HEADER} "static const char ${SHADER_SRC_NAME_WE}_comp_data[] = {${comp_data_hex}};\n")
