//import os

// win: FILETIME
// https://docs.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime
struct Filetime {
	dw_low_date_time  u32
	dw_high_date_time u32
}

struct SysTime {
	year u16
	month u16
	day_of_week u16
	day u16
	hour u16
	minute u16
	second u16
	milliseconds u16
}

// win: WIN32_FIND_DATA
// https://docs.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-win32_find_dataw
struct FileInfo {
mut:
	file_attributes    u32
	creation_time      Filetime
	last_access_time   Filetime
	last_write_time    Filetime
	file_size_high      u32
	file_size_low       u32
	dw_reserved0          u32
	dw_reserved1          u32
	file_name           [260]u16 // max_path_len = 260
	alternate_file_name [14]u16  // 14
	dw_file_type          u32 // old
	dw_creator_type       u32 // old
	w_finder_flags        u16 // old
	full_path string
	name string
}

[inline]
fn (sys_time SysTime) nice_time() string {
	return '$sys_time.year/$sys_time.month/$sys_time.day ${sys_time.hour:02}:${sys_time.minute:02}:${sys_time.second:02}'
}

[inline]
fn (file_info FileInfo) write_time() SysTime {
	mut sys_time := SysTime{}
	C.FileTimeToSystemTime(voidptr(&file_info.last_write_time), voidptr(&sys_time))
	return sys_time
}

[inline]
fn (file_info FileInfo) access_time() SysTime {
	mut sys_time := SysTime{}
	C.FileTimeToSystemTime(voidptr(&file_info.last_access_time), voidptr(&sys_time))
	return sys_time
}

[inline]
fn (mut file_info FileInfo) name() {
	file_info.name = unsafe{string_from_wide(&file_info.file_name[0])}
}

[inline]
fn (file_info FileInfo) file_size() int {
	return (file_info.file_size_high * (C.MAXDWORD+1)) + file_info.file_size_low
}

[inline]
fn (file_info FileInfo) is_dir() bool {
	if file_info.file_attributes == u32(C.INVALID_FILE_ATTRIBUTES) {
		return false
	}
	if file_info.file_attributes & u32(C.FILE_ATTRIBUTE_DIRECTORY) != 0 {
		return true
	}
	return false
}

[direct_array_access]
fn list_content(path string) []FileInfo {
	mut find_file_data := FileInfo{}
	mut dir_files := []FileInfo{}
	// NOTE:TODO: once we have a way to convert utf16 wide character to utf8
	// we should use FindFirstFileW and FindNextFileW
	handle_to_find_files := C.FindFirstFile('${path}\\*'.to_wide(), voidptr(&find_file_data))
	find_file_data.name()
	if find_file_data.name != '.' && find_file_data.name != '..' {
		dir_files << find_file_data
	}
	for C.FindNextFile(handle_to_find_files, voidptr(&find_file_data)) > 0 {
		find_file_data.name()
		if find_file_data.name != '.' && find_file_data.name != '..' {
			dir_files << find_file_data
		}
	}
	C.FindClose(handle_to_find_files)
	return dir_files
}

[direct_array_access]
fn search(search_text string, actual_path string) []FileInfo{
	mut output := []FileInfo{}
	mut path := ""
	mut next_dirs := []string{}
	next_dirs << actual_path.replace('/', '\\')
	for next_dirs.len > 0{
		path = next_dirs.pop()
		for mut elem in list_content(path) {
			if elem.is_dir() {
				elem.full_path = "$path\\${elem.name}"
				next_dirs << elem.full_path
				if elem.name.contains(search_text){
					output << elem
				}
			}else{
				if elem.name.contains(search_text){
					elem.full_path = "$path\\${elem.name}"
					output << elem
				}
			}
		}
	}
	return output
}